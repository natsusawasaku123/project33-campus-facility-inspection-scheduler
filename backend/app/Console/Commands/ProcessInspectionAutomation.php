<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class ProcessInspectionAutomation extends Command
{
    protected $signature = 'inspections:process';

    protected $description = 'Generate inspections for due recurring plans';

    public function handle(): int
    {
        $runAt = now('UTC')->toDateTimeString();
        $runId = (string) Str::uuid();
        $generated = 0;

        $plans = DB::table('inspection_plans')
            ->where('next_due_at', '<=', $runAt)
            ->orderBy('id')
            ->get(['id', 'next_due_at', 'repeat_days']);

        foreach ($plans as $plan) {
            $scheduledAt = $plan->next_due_at;
            $nextDueAt = Carbon::parse($scheduledAt, 'UTC')
                ->addDays((int) $plan->repeat_days)
                ->toDateTimeString();

            $inspectionId = DB::transaction(
                function () use ($plan, $scheduledAt, $nextDueAt, $runAt): ?int {
                    $updated = DB::table('inspection_plans')
                        ->where('id', $plan->id)
                        ->where('next_due_at', $scheduledAt)
                        ->update([
                            'next_due_at' => $nextDueAt,
                            'updated_at' => $runAt,
                        ]);

                    if ($updated !== 1) {
                        return null;
                    }

                    $occurrence = [
                        'inspection_plan_id' => $plan->id,
                        'scheduled_at' => $scheduledAt,
                    ];

                    if (DB::table('inspections')->where($occurrence)->exists()) {
                        return null;
                    }

                    return DB::table('inspections')->insertGetId([
                        ...$occurrence,
                        'status' => 'scheduled',
                        'created_at' => $runAt,
                        'updated_at' => $runAt,
                    ]);
                },
                3
            );

            if ($inspectionId === null) {
                continue;
            }

            $generated++;

            Log::info('inspection.generated', [
                'run_id' => $runId,
                'plan_id' => $plan->id,
                'inspection_id' => $inspectionId,
                'scheduled_at_utc' => $scheduledAt,
                'next_due_at_utc' => $nextDueAt,
            ]);
        }

        Log::info('inspection.cycle_finished', [
            'run_id' => $runId,
            'checked_at_utc' => $runAt,
            'generated' => $generated,
        ]);

        $this->info("Generated {$generated} inspection(s).");

        return self::SUCCESS;
    }
}
