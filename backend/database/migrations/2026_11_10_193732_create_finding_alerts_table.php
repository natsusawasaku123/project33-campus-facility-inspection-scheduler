<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('finding_alerts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('finding_id')->constrained('findings');
            $table->string('kind', 20);
            $table->string('status', 20)->default('pending');
            $table->foreignId('recipient_user_id')->nullable()->constrained('users');
            $table->unsignedTinyInteger('attempts')->default(0);
            $table->dateTime('next_attempt_at')->nullable();
            $table->dateTime('delivered_at')->nullable();
            $table->string('error_code', 60)->nullable();
            $table->timestamps();

            $table->unique(['finding_id', 'kind']);
            $table->index(['recipient_user_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('finding_alerts');
    }
};
