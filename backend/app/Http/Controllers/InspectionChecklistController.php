<?php

namespace App\Http\Controllers;

use Illuminate\Database\Query\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Validation\Rule;

class InspectionChecklistController extends Controller
{
    private const ITEMS = [
        'exits_clear' => 'Exits and walkways are clear',
        'equipment_safe' => 'Equipment is safe to use',
        'room_clean' => 'Room is clean and free of hazards',
    ];

    public function show(Request $request, string $inspection): JsonResponse
    {
        $query = $this->assignedInspection($request, $inspection);

        return response()->json($this->readChecklist($query));
    }

    public function update(Request $request, string $inspection): JsonResponse
    {
        $query = $this->assignedInspection($request, $inspection);
        abort_unless($query->exists(), 404);

        $keys = implode(',', array_keys(self::ITEMS));
        $validated = $request->validate([
            'results' => ['required', "array:{$keys}", "required_array_keys:{$keys}"],
            'results.*' => ['required', 'string', 'in:pass,fail'],
        ]);

        $results = $validated['results'];
        ksort($results);
        $completedAt = now('UTC')->toDateTimeString();

        (clone $query)->where('status', 'scheduled')->update([
            'checklist_results' => json_encode($results, JSON_THROW_ON_ERROR),
            'status' => 'completed',
            'completed_at' => $completedAt,
            'updated_at' => $completedAt,
        ]);

        $checklist = $this->readChecklist($query);
        $savedResults = $checklist['results'] ?? [];
        ksort($savedResults);

        if ($checklist['status'] !== 'completed' || $savedResults !== $results) {
            return response()->json([
                'message' => 'This inspection is closed to new submissions.',
            ], 409);
        }

        return response()->json($checklist);
    }

public function storeFinding(Request $request, string $inspection): JsonResponse
{
    $checklist = $this->readChecklist(
        $this->assignedInspection($request, $inspection)
    );

    abort_unless(
        $checklist['status'] === 'completed',
        409,
        'Complete the checklist before recording a finding.'
    );

    $data = $request->validate([
        'checklist_key' => ['required', 'string', 'max:80'],
        'description' => ['required', 'string', 'max:1000'],
        'assigned_to_user_id' => [
            'required',
            'integer',
            Rule::exists('users', 'id')->where('role', 'maintenance'),
        ],
        'due_at' => ['required', 'string', 'date', 'after:now'],
    ]);

    $itemKey = $data['checklist_key'];
    abort_unless(
        ($checklist['results'][$itemKey] ?? null) === 'fail',
        422,
        'Choose a failed checklist item.'
    );

    $dueAt = Carbon::parse($data['due_at'], 'UTC')->setTimezone('UTC');
    $now = now('UTC')->toDateTimeString();
    $finding = [
        'inspection_id' => $checklist['inspection_id'],
        'checklist_key' => $itemKey,
        'description' => $data['description'],
        'assigned_to_user_id' => (int) $data['assigned_to_user_id'],
        'due_at' => $dueAt->toDateTimeString(),
        'status' => 'open',
    ];

    try {
        $id = DB::table('findings')->insertGetId([
            ...$finding,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
    } catch (UniqueConstraintViolationException $error) {
        $existingId = DB::table('findings')
            ->where('inspection_id', $finding['inspection_id'])
            ->where('checklist_key', $itemKey)
            ->value('id');

        if ($existingId === null) {
            throw $error;
        }

        return response()->json([
            'message' => 'A finding already exists for this item.',
            'finding_id' => $existingId,
        ], 409);
    }

    $finding['due_at'] = $dueAt->toIso8601String();

    return response()->json(['id' => $id, ...$finding], 201);
}

    private function assignedInspection(Request $request, string $inspection): Builder
    {
        $inspector = $request->user();
        abort_unless($inspector->role === 'inspector', 403);

        $plans = DB::table('inspection_plans')
            ->select('id')
            ->where('inspector_id', $inspector->id);

        return DB::table('inspections')
            ->where('id', $inspection)
            ->whereIn('inspection_plan_id', $plans);
    }

    private function readChecklist(Builder $query): array
    {
        $row = $query->first(['id', 'status', 'completed_at', 'checklist_results']);
        abort_if($row === null, 404);

        return [
            'inspection_id' => (int) $row->id,
            'status' => $row->status,
            'items' => self::ITEMS,
            'results' => $row->checklist_results === null
                ? null
                : json_decode($row->checklist_results, true, 512, JSON_THROW_ON_ERROR),
            'completed_at' => $row->completed_at === null
                ? null
                : Carbon::parse($row->completed_at, 'UTC')->toIso8601String(),
        ];
    }
}
