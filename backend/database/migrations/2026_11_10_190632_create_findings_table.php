<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('findings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('inspection_id')->constrained('inspections');
            $table->string('checklist_key', 80);
            $table->text('description');
            $table->foreignId('assigned_to_user_id')->constrained('users');
            $table->dateTime('due_at');
            $table->string('status')->default('open');
            $table->timestamps();

            $table->unique(['inspection_id', 'checklist_key']);
            $table->index(['status', 'due_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('findings');
    }
};
