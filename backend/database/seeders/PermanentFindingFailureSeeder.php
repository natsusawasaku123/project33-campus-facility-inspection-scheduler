<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class PermanentFindingFailureSeeder extends Seeder
{
    public function run(): void
    {
        if (! app()->environment('local')) {
            throw new RuntimeException('This demo requires APP_ENV=local.');
        }

        $findingId = DB::transaction(function (): int {
            $description = '[Local demo] Maintenance recipient unavailable';

            $existingId = DB::table('findings')
                ->where('description', $description)
                ->value('id');

            if ($existingId !== null) {
                return (int) $existingId;
            }

            $source = DB::table('findings as f')
                ->join('inspections as i', 'i.id', '=', 'f.inspection_id')
                ->join('inspection_plans as p', 'p.id', '=', 'i.inspection_plan_id')
                ->join('users as u', 'u.id', '=', 'p.inspector_id')
                ->where('f.id', 1)
                ->where('i.status', 'completed')
                ->where('u.role', 'inspector')
                ->first([
                    'i.inspection_plan_id',
                    'i.checklist_results',
                    'p.first_due_at',
                    'p.inspector_id',
                    'f.checklist_key',
                ]);

            if ($source === null || $source->checklist_results === null) {
                throw new RuntimeException('Create the Step 5A demo finding first.');
            }

            $now = Carbon::now('UTC');
            $timestamp = $now->toDateTimeString();
            $demoSlot = Carbon::parse($source->first_due_at, 'UTC')
                ->subSecond()
                ->toDateTimeString();

            $inspectionId = DB::table('inspections')->insertGetId([
                'inspection_plan_id' => $source->inspection_plan_id,
                'scheduled_at' => $demoSlot,
                'status' => 'completed',
                'completed_at' => $now->copy()->subMinutes(2)->toDateTimeString(),
                'checklist_results' => $source->checklist_results,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ]);

            return DB::table('findings')->insertGetId([
                'inspection_id' => $inspectionId,
                'checklist_key' => $source->checklist_key,
                'description' => $description,
                'assigned_to_user_id' => $source->inspector_id,
                'due_at' => $now->copy()->subMinute()->toDateTimeString(),
                'status' => 'open',
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ]);
        }, 3);

        $this->command?->info("Permanent failure demo finding #{$findingId}.");
    }
}
