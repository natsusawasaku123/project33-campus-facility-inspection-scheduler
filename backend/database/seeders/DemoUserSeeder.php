<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use RuntimeException;

class DemoUserSeeder extends Seeder
{
    public function run(): void
    {
        if (!app()->environment('local', 'testing')) {
            throw new RuntimeException('Run this seeder in a local or testing environment.');
        }

        $password = config('facility.demo_password');

        if (!is_string($password) || strlen($password) < 12 || strlen($password) > 64) {
            throw new RuntimeException('Set FACILITY_DEMO_PASSWORD to 12–64 characters in .env.');
        }

        $roles = [
            'supervisor' => 'Demo Supervisor',
            'inspector' => 'Demo Inspector',
            'maintenance' => 'Demo Maintenance',
            'custodian' => 'Demo Custodian',
        ];

        $users = [];

        foreach ($roles as $role => $name) {
            $users[] = [
                'name' => $name,
                'email' => "{$role}@example.test",
                'role' => $role,
                'password' => Hash::make($password),
            ];
        }

        User::query()->upsert($users, ['email'], ['name', 'role', 'password']);
    }
}
