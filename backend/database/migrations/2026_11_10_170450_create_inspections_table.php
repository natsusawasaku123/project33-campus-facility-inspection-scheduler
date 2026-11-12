<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('inspections', function (Blueprint $table) {
            $table->id();
            $table->foreignId('inspection_plan_id')->constrained('inspection_plans');
            $table->dateTime('scheduled_at');
            $table->string('status')->default('scheduled');
            $table->dateTime('completed_at')->nullable();
            $table->timestamps();

            $table->unique(['inspection_plan_id', 'scheduled_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('inspections');
    }
};
