<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class ProcessFindingAlerts extends Command
{
    private const RETRY_SECONDS = [1 => 60, 2 => 120];

    protected $signature = 'findings:process
        {--demo-finding= : Finding ID for a simulated local delivery failure}
        {--demo-failures=1 : Number of temporary failures to simulate}';

    protected $description = 'Record overdue finding alerts and supervisor escalations';

    public function handle(): int
    {
        if ($this->option('demo-finding') !== null && ! app()->environment('local')) {
            $this->error('The demo failure option requires APP_ENV=local.');

            return self::FAILURE;
        }

        $runAt = Carbon::now('UTC');
        $checkedAt = $runAt->toDateTimeString();
        $runId = (string) Str::uuid();
        $escalationMinutes = max(1, (int) config('facility.finding_escalation_minutes', 1440));
        $escalationCutoff = $runAt->copy()->subMinutes($escalationMinutes)->toDateTimeString();

        $findings = DB::table('findings')
            ->where('status', 'open')
            ->where('due_at', '<=', $checkedAt)
            ->orderBy('id')
            ->get(['id', 'assigned_to_user_id', 'due_at']);

        foreach ($findings as $finding) {
            $this->processAlert($finding, 'overdue', $runAt, $runId);

            if ($finding->due_at <= $escalationCutoff) {
                $this->processAlert($finding, 'escalation', $runAt, $runId);
            }
        }

        $checked = $findings->count();
        Log::info('finding.automation_cycle_finished', [
            'run_id' => $runId,
            'checked_at_utc' => $checkedAt,
            'findings_checked' => $checked,
        ]);
        $this->info("Checked {$checked} overdue finding(s).");

        return self::SUCCESS;
    }

    private function processAlert(object $finding, string $kind, Carbon $runAt, string $runId): void
    {
        $checkedAt = $runAt->toDateTimeString();
        $identity = ['finding_id' => $finding->id, 'kind' => $kind];
        $lookup = DB::table('finding_alerts')->where($identity);
        $alert = $lookup->first();

        if ($alert === null) {
            try {
                DB::table('finding_alerts')->insert([
                    ...$identity,
                    'next_attempt_at' => $checkedAt,
                    'created_at' => $checkedAt,
                    'updated_at' => $checkedAt,
                ]);
            } catch (UniqueConstraintViolationException) {
                // A concurrent run created this alert.
            }

            $alert = $lookup->first();
        }

        if ($alert === null || $alert->status !== 'pending' || $alert->next_attempt_at > $checkedAt) {
            return;
        }

        $attempt = $alert->attempts + 1;
        $deliveryRecipient = $this->recipientFor($finding, $kind);

        $failure = match (true) {
            $deliveryRecipient === null => 'recipient_unavailable',
            $kind === 'overdue'
                && (string) $finding->id === $this->option('demo-finding')
                && $attempt <= (int) $this->option('demo-failures') => 'demo_transient_delivery',
            default => null,
        };

        $delay = $failure === 'demo_transient_delivery'
            ? (self::RETRY_SECONDS[$attempt] ?? null)
            : null;

        $status = match (true) {
            $failure === null => 'delivered',
            $delay !== null => 'pending',
            default => 'manual_review',
        };

        $recipientId = match ($status) {
            'delivered' => $deliveryRecipient,
            'manual_review' => $this->recipientFor($finding, 'escalation'),
            default => null,
        };

        $nextAttempt = $delay === null
            ? null
            : $runAt->copy()->addSeconds($delay)->toDateTimeString();

        $openFindings = DB::table('findings')->select('id')->where('status', 'open');
        $changed = DB::table('finding_alerts')
            ->where('id', $alert->id)
            ->where('status', 'pending')
            ->where('attempts', $alert->attempts)
            ->where('next_attempt_at', '<=', $checkedAt)
            ->whereIn('finding_id', $openFindings)
            ->update([
                'status' => $status,
                'attempts' => $attempt,
                'recipient_user_id' => $recipientId,
                'next_attempt_at' => $nextAttempt,
                'delivered_at' => $status === 'delivered' ? $checkedAt : null,
                'error_code' => $failure,
                'updated_at' => $checkedAt,
            ]);

        if ($changed !== 1) {
            return;
        }

        Log::info('finding.alert_attempt', [
            'run_id' => $runId,
            'finding_id' => $finding->id,
            'alert_id' => $alert->id,
            'kind' => $kind,
            'attempt' => $attempt,
            'status' => $status,
            'recipient_user_id' => $recipientId,
            'error_code' => $failure,
            'next_attempt_at_utc' => $nextAttempt,
        ]);
        $this->line("Finding #{$finding->id} {$kind} | attempt {$attempt} | {$status}");
    }

    private function recipientFor(object $finding, string $kind): ?int
    {
        $users = DB::table('users');

        if ($kind === 'overdue') {
            return $users->where('id', $finding->assigned_to_user_id)
                ->where('role', 'maintenance')
                ->value('id');
        }

        return $users->where('role', 'supervisor')->orderBy('id')->value('id');
    }
}
