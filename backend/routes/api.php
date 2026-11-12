<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Carbon;
use Illuminate\Validation\Rule;
use App\Http\Controllers\InspectionChecklistController;

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');
Route::get('/health', function () {
    return response()->json(['status' => 'ok']);
});
Route::get('/facilities', function () {
    $facilities = DB::table('facilities')
        ->orderBy('name')
        ->get(['id', 'name']);

    return response()->json($facilities);
});
Route::post('/auth/login', function (Request $request) {
    $credentials = $request->validate([
        'email' => ['required', 'email', 'max:255'],
        'password' => ['required', 'string', 'max:64'],
    ]);

    if (!Auth::once($credentials)) {
        return response()->json(['message' => 'Invalid email or password.'], 401);
    }

    $user = Auth::user();

    if ($user->role === null) {
        return response()->json(['message' => 'This account needs a role.'], 403);
    }

    $token = $user->createToken('project33-demo', ['*'], now()->addHour());

    return response()->json([
        'token' => $token->plainTextToken,
        'user' => $user->only(['id', 'name', 'email', 'role']),
    ])->header('Cache-Control', 'no-store');
})->middleware('throttle:5,1');
Route::get('/inspectors', function (Request $request) {
    if ($request->user()->role !== 'supervisor') {
        return response()->json([
            'message' => 'Only supervisors can view the inspector list.',
        ], 403);
    }

    $inspectors = DB::table('users')
        ->where('role', 'inspector')
        ->orderBy('name')
        ->get(['id', 'name']);

    return response()->json($inspectors);
})->middleware('auth:sanctum');
Route::post('/plans', function (Request $request) {
    if ($request->user()->role !== 'supervisor') {
        return response()->json([
            'message' => 'Only supervisors can create inspection plans.',
        ], 403);
    }

    $data = $request->validate([
        'facility_id' => ['required', 'integer', 'exists:facilities,id'],
        'inspector_id' => [
            'required',
            'integer',
            Rule::exists('users', 'id')->where('role', 'inspector'),
        ],
        'first_due_at' => ['required', 'string', 'date', 'after:now'],
        'repeat_days' => ['required', 'integer', 'min:1', 'max:365'],
    ]);

    $dueAt = Carbon::parse($data['first_due_at'])->utc();
    $now = now('UTC');

    $plan = [
        'facility_id' => (int) $data['facility_id'],
        'inspector_id' => (int) $data['inspector_id'],
        'repeat_days' => (int) $data['repeat_days'],
    ];

    $id = DB::table('inspection_plans')->insertGetId([
        ...$plan,
        'first_due_at' => $dueAt->toDateTimeString(),
        'next_due_at' => $dueAt->toDateTimeString(),
        'created_at' => $now,
        'updated_at' => $now,
    ]);

    return response()->json([
        'id' => $id,
        ...$plan,
        'first_due_at' => $dueAt->toIso8601String(),
        'next_due_at' => $dueAt->toIso8601String(),
    ], 201);
})->middleware('auth:sanctum');
Route::get('/inspections', function (Request $request) {
    $inspector = $request->user();

    if ($inspector->role !== 'inspector') {
        return response()->json([
            'message' => 'Only inspectors can view assigned inspections.',
        ], 403);
    }

    $inspections = DB::table('inspections')
        ->join('inspection_plans', 'inspection_plans.id', '=', 'inspections.inspection_plan_id')
        ->join('facilities', 'facilities.id', '=', 'inspection_plans.facility_id')
        ->where('inspection_plans.inspector_id', $inspector->id)
        ->orderByDesc('inspections.scheduled_at')
        ->orderByDesc('inspections.id')
        ->get([
            'inspections.id',
            'inspections.inspection_plan_id',
            'inspection_plans.inspector_id',
            'facilities.name as facility_name',
            'inspections.scheduled_at',
            'inspections.status',
        ]);

    foreach ($inspections as $inspection) {
        $inspection->scheduled_at = Carbon::parse($inspection->scheduled_at, 'UTC')
            ->toIso8601String();
    }

    return response()->json($inspections);
})->middleware('auth:sanctum');
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/inspections/{inspection}/checklist', [InspectionChecklistController::class, 'show'])
        ->whereNumber('inspection');

    Route::put('/inspections/{inspection}/checklist', [InspectionChecklistController::class, 'update'])
        ->whereNumber('inspection');

    Route::post('/inspections/{inspection}/findings', [InspectionChecklistController::class, 'storeFinding'])
           ->whereNumber('inspection');
    Route::get('/finding-alerts', function (Request $request) {
        $user = $request->user();

        abort_unless(in_array($user->role, ['maintenance', 'supervisor'], true), 403);

        $alerts = DB::table('finding_alerts as a')
            ->join('findings as f', 'f.id', '=', 'a.finding_id')
            ->join('inspections as i', 'i.id', '=', 'f.inspection_id')
            ->join('inspection_plans as p', 'p.id', '=', 'i.inspection_plan_id')
            ->join('facilities as room', 'room.id', '=', 'p.facility_id')
            ->where(function ($query) use ($user) {
                $query->where('a.recipient_user_id', $user->id)
                    ->where('a.status', 'delivered');

                if ($user->role === 'supervisor') {
                    $query->orWhere('a.status', 'manual_review');
                }
            })
            ->orderByDesc('a.id')
            ->get([
                'a.id as alert_id',
                'a.finding_id',
                'a.kind',
                'a.status',
                'a.attempts',
                'a.error_code',
                'a.recipient_user_id',
                'a.updated_at as processed_at',
                'f.description',
                'f.due_at',
                'room.name as facility_name',
            ]);

        foreach ($alerts as $alert) {
            $alert->due_at = Carbon::parse($alert->due_at, 'UTC')->toIso8601String();
            $alert->processed_at = Carbon::parse($alert->processed_at, 'UTC')
                ->toIso8601String();

            $alert->review_action = $alert->status === 'manual_review'
                ? 'Review the failed alert and confirm an eligible recipient.'
                : null;
        }

        return response()->json($alerts);
    })->middleware('auth:sanctum');
    Route::get('/compliance-summary', function (Request $request) {
        abort_unless($request->user()->role === 'supervisor', 403);

        $summary = DB::transaction(function (): array {
            $now = Carbon::now('UTC');
            $timezone = 'Asia/Manila';
            $day = $now->copy()->setTimezone($timezone)->startOfDay();

            $startUtc = $day->copy()->setTimezone('UTC')->toDateTimeString();
            $endUtc = $day->copy()->addDay()->setTimezone('UTC')->toDateTimeString();

            $inspections = DB::table('inspections')
                ->where('scheduled_at', '>=', $startUtc)
                ->where('scheduled_at', '<', $endUtc)
                ->selectRaw('COUNT(*) AS scheduled')
                ->selectRaw(
                    'COUNT(CASE WHEN status = ? THEN 1 END) AS completed',
                    ['completed']
                )
                ->first();

            $findings = DB::table('findings')
                ->where('status', 'open')
                ->selectRaw('COUNT(*) AS open_count')
                ->selectRaw(
                    'COUNT(CASE WHEN due_at <= ? THEN 1 END) AS overdue',
                    [$now->toDateTimeString()]
                )
                ->first();

            $alerts = DB::table('finding_alerts as a')
                ->join('findings as f', 'f.id', '=', 'a.finding_id')
                ->where('f.status', 'open')
                ->selectRaw(
                    'COUNT(CASE WHEN a.kind = ? AND a.status = ? THEN 1 END) AS escalated',
                    ['escalation', 'delivered']
                )
                ->selectRaw(
                    'COUNT(CASE WHEN a.status = ? THEN 1 END) AS manual_review',
                    ['manual_review']
                )
                ->first();

            $scheduled = (int) $inspections->scheduled;
            $completed = (int) $inspections->completed;

            return [
                'date' => $day->toDateString(),
                'timezone' => $timezone,
                'as_of' => $now->toIso8601String(),
                'inspections_scheduled' => $scheduled,
                'inspections_completed' => $completed,
                'completion_percent' => $scheduled === 0
                    ? null
                    : round(100 * $completed / $scheduled, 1),
                'open_findings' => (int) $findings->open_count,
                'overdue_findings' => (int) $findings->overdue,
                'escalated_open_findings' => (int) $alerts->escalated,
                'manual_review_alerts' => (int) $alerts->manual_review,
            ];
        });

        return response()->json($summary);
    })->middleware('auth:sanctum');
});

