<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Middleware\TrustProxies;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use Laravel\Sanctum\PersonalAccessToken;
use Mockery;
use Psr\Log\LoggerInterface;
use Tests\TestCase;

class SecureIntegrationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['security.require_https' => true, 'app.debug' => false]);
        $this->app['url']->forceRootUrl('https://localhost');
        $this->app['url']->forceScheme('https');
        $this->withServerVariables(['HTTPS' => 'on', 'REMOTE_ADDR' => '127.0.0.1']);
    }

    private function account(string $role): User
    {
        return User::factory()->create(['role' => $role]);
    }

    private function bearer(User $user, $expires = null): string
    {
        return $user->createToken('security-test', ['*'], $expires ?? now()->addHour())->plainTextToken;
    }

    private function inspection(User $inspector): int
    {
        $now = now()->toDateTimeString();
        $facility = DB::table('facilities')->insertGetId(['name' => 'Test Room '.Str::uuid()]);
        $plan = DB::table('inspection_plans')->insertGetId([
            'facility_id' => $facility, 'inspector_id' => $inspector->id,
            'first_due_at' => $now, 'next_due_at' => $now, 'repeat_days' => 1,
        ]);

        return DB::table('inspections')->insertGetId([
            'inspection_plan_id' => $plan, 'scheduled_at' => $now,
            'status' => 'scheduled',
        ]);
    }

    public function test_login_hashes_tokens_limits_user_data_and_sets_security_headers(): void
    {
        $password = Str::random(24);
        $user = User::factory()->create(['role' => 'supervisor', 'password' => Hash::make($password)]);
        $response = $this->postJson('/api/auth/login', ['email' => $user->email, 'password' => $password]);
        $response->assertOk()->assertJsonStructure(['token', 'expires_at', 'user' => ['id', 'name', 'role']])
            ->assertHeader('Cache-Control')
            ->assertHeader('X-Content-Type-Options', 'nosniff')
            ->assertHeader('Strict-Transport-Security', 'max-age=300');
        $this->assertSame(['id', 'name', 'role'], array_keys($response->json('user')));
        $this->assertStringContainsString('no-store', $response->headers->get('Cache-Control'));
        $plain = $response->json('token');
        $stored = PersonalAccessToken::findToken($plain);
        $this->assertNotNull($stored);
        $this->assertSame(hash('sha256', explode('|', $plain, 2)[1]), $stored->token);
        $this->assertTrue(Hash::check($password, $user->password));
        $this->assertNotSame($password, $user->password);
        $this->assertEqualsWithDelta(3600, now()->diffInSeconds($stored->expires_at), 2);
    }

    public function test_invalid_login_and_role_do_not_issue_a_token(): void
    {
        $password = Str::random(24);
        $user = User::factory()->create(['role' => 'unapproved', 'password' => Hash::make($password)]);
        $this->postJson('/api/auth/login', ['email' => $user->email, 'password' => 'incorrect-test-value'])->assertUnauthorized();
        $this->postJson('/api/auth/login', ['email' => $user->email, 'password' => $password])->assertForbidden();
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_missing_invalid_altered_and_expired_tokens_are_rejected(): void
    {
        $user = $this->account('inspector');
        $valid = $this->bearer($user);
        $this->get('/api/user')->assertUnauthorized()->assertJsonStructure(['message']);
        $this->withToken('invalid-test-token')->getJson('/api/user')->assertUnauthorized();
        $altered = substr($valid, 0, -1).(str_ends_with($valid, 'a') ? 'b' : 'a');
        $this->withToken($altered)->getJson('/api/user')->assertUnauthorized();
        $expired = $this->bearer($user, now()->subSecond());
        $this->withToken($expired)->getJson('/api/user')->assertUnauthorized();
        $this->withToken($valid)->getJson('/api/user')->assertOk()
            ->assertExactJson($user->only(['id', 'name', 'role']));
    }

    public function test_logout_revokes_the_current_token_without_revoking_other_sessions(): void
    {
        $user = $this->account('inspector');
        $first = $this->bearer($user);
        $other = $this->bearer($user);
        $this->withToken($first)->postJson('/api/auth/logout')->assertNoContent();
        $this->assertNull(PersonalAccessToken::findToken($first));
        $this->assertNotNull(PersonalAccessToken::findToken($other));
        $this->app['auth']->forgetGuards();
        $this->withToken($first)->getJson('/api/user')->assertUnauthorized();
        $this->withToken($other)->getJson('/api/user')->assertOk();
    }

    public function test_wrong_role_cannot_create_plans_or_read_supervisor_summary(): void
    {
        $this->withToken($this->bearer($this->account('maintenance')))
            ->postJson('/api/plans', ['role' => 'supervisor'])->assertForbidden();
        $this->getJson('/api/compliance-summary')->assertForbidden();
        $this->assertDatabaseCount('inspection_plans', 0);
    }

    public function test_changing_inspection_id_cannot_read_or_modify_another_inspectors_record(): void
    {
        $owner = $this->account('inspector');
        $other = $this->account('inspector');
        $id = $this->inspection($owner);
        $this->withToken($this->bearer($other))->getJson("/api/inspections/{$id}/checklist")->assertNotFound();
        $this->putJson("/api/inspections/{$id}/checklist", ['results' => [
            'exits_clear' => 'pass', 'equipment_safe' => 'pass', 'room_clean' => 'pass',
        ]])->assertNotFound();
        $this->postJson("/api/inspections/{$id}/findings", [])->assertNotFound();
        $this->assertDatabaseHas('inspections', ['id' => $id, 'status' => 'scheduled', 'checklist_results' => null]);
        $this->assertDatabaseCount('findings', 0);
    }

    public function test_invalid_values_and_extra_checklist_keys_do_not_change_data(): void
    {
        $inspector = $this->account('inspector');
        $id = $this->inspection($inspector);
        $this->withToken($this->bearer($inspector))->putJson("/api/inspections/{$id}/checklist", [
            'results' => ['exits_clear' => 'unsafe', 'equipment_safe' => 'pass', 'room_clean' => 'pass'],
        ])->assertUnprocessable();
        $this->putJson("/api/inspections/{$id}/checklist", ['results' => [
            'exits_clear' => 'pass', 'equipment_safe' => 'pass', 'room_clean' => 'pass', 'extra' => 'pass',
        ]])->assertUnprocessable();
        $this->assertDatabaseHas('inspections', ['id' => $id, 'status' => 'scheduled']);
    }

    public function test_supervisor_can_create_a_valid_plan_but_invalid_plan_is_rejected(): void
    {
        $inspector = $this->account('inspector');
        $facility = DB::table('facilities')->insertGetId(['name' => 'Validation Test Room']);
        $data = ['facility_id' => $facility, 'inspector_id' => $inspector->id,
            'first_due_at' => now()->addHour()->toIso8601String(), 'repeat_days' => 1];
        $this->withToken($this->bearer($this->account('supervisor')))
            ->postJson('/api/plans', [...$data, 'repeat_days' => 0])->assertUnprocessable();
        $this->assertDatabaseCount('inspection_plans', 0);
        $this->postJson('/api/plans', $data)->assertCreated();
        $this->assertDatabaseCount('inspection_plans', 1);
    }

    public function test_http_and_untrusted_forwarded_https_are_rejected(): void
    {
        $this->withServerVariables(['HTTPS' => 'off', 'REMOTE_ADDR' => '198.51.100.10'])
            ->withHeader('X-Forwarded-Proto', 'https')->postJson('http://localhost/api/auth/login', [])->assertStatus(400)
            ->assertExactJson(['message' => 'HTTPS is required.']);
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_only_the_configured_proxy_can_assert_https(): void
    {
        TrustProxies::at(['127.0.0.1']);
        $this->withServerVariables(['HTTPS' => 'off', 'REMOTE_ADDR' => '127.0.0.1'])
            ->withHeader('X-Forwarded-Proto', 'https')->getJson('http://localhost/api/health')->assertOk();
    }

    public function test_a_nonlocal_environment_cannot_disable_https_with_a_configuration_flag(): void
    {
        $this->app['env'] = 'production';
        config(['security.require_https' => false]);
        $this->withServerVariables(['HTTPS' => 'off', 'REMOTE_ADDR' => '198.51.100.10'])
            ->getJson('http://localhost/api/health')->assertStatus(400);
    }

    public function test_login_rate_limit_rejects_the_sixth_attempt(): void
    {
        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/auth/login', ['email' => 'invalid@example.test', 'password' => 'invalid'])
                ->assertUnauthorized();
        }
        $this->postJson('/api/auth/login', ['email' => 'invalid@example.test', 'password' => 'invalid'])
            ->assertStatus(429)->assertHeader('Retry-After');
    }

    public function test_security_logs_and_server_errors_do_not_expose_request_or_exception_contents(): void
    {
        $entries = [];
        $logger = Mockery::mock(LoggerInterface::class);
        foreach (['info', 'error'] as $level) {
            $logger->shouldReceive($level)->andReturnUsing(function ($message, $context) use (&$entries) {
                $entries[] = [$message, $context];
            });
        }
        Log::shouldReceive('channel')->with('security')->andReturn($logger);
        $canary = 'PRIVATE-CANARY-'.Str::uuid();
        Route::middleware('api')->post('/api/test-exception', function () use ($canary) {
            throw new \RuntimeException($canary);
        });
        config(['app.debug' => true]);
        $response = $this->withHeader('Authorization', "Bearer {$canary}")
            ->postJson('/api/test-exception?private='.$canary, ['password' => $canary, 'description' => $canary]);
        $response->assertStatus(500)->assertJsonStructure(['message', 'request_id']);
        $this->assertNotEmpty($entries);
        $this->assertStringNotContainsString($canary, json_encode($entries));
        $this->assertStringNotContainsString($canary, $response->getContent());
        $this->assertStringNotContainsString('trace', $response->getContent());
        Route::middleware('api')->get('/api/test-http-error', fn () => abort(503, $canary));
        $httpError = $this->getJson('/api/test-http-error')->assertStatus(503);
        $this->assertStringNotContainsString($canary, $httpError->getContent());
    }

    public function test_cors_permits_only_an_explicit_origin(): void
    {
        config(['cors.allowed_origins' => ['https://localhost:8443', 'https://approved.example']]);
        $this->withHeaders(['Origin' => 'https://untrusted.example', 'Access-Control-Request-Method' => 'POST'])
            ->options('/api/auth/login')->assertHeaderMissing('Access-Control-Allow-Origin');
        $this->withHeader('Origin', 'https://localhost:8443')->options('/api/auth/login')
            ->assertHeader('Access-Control-Allow-Origin', 'https://localhost:8443');
    }
}
