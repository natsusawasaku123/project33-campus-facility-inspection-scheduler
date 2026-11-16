<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Laravel\Sanctum\PersonalAccessToken;

class AuthController extends Controller
{
    public function login(Request $request)
    {
        $credentials = $request->validate([
            'email' => ['required', 'email', 'max:255'],
            'password' => ['required', 'string', 'max:64'],
        ]);

        if (! Auth::once($credentials)) {
            return response()->json(['message' => 'Invalid email or password.'], 401);
        }

        $user = Auth::user();
        if (! in_array($user->role, ['supervisor', 'inspector', 'maintenance', 'custodian'], true)) {
            return response()->json(['message' => 'This account needs an approved role.'], 403);
        }

        $expiresAt = now()->addHour();
        $token = $user->createToken('project33-web', ['*'], $expiresAt);

        return response()->json([
            'token' => $token->plainTextToken,
            'expires_at' => $expiresAt->toIso8601String(),
            'user' => $user->only(['id', 'name', 'role']),
        ]);
    }

    public function logout(Request $request)
    {
        $token = $request->user()->currentAccessToken();
        if ($token instanceof PersonalAccessToken) {
            $token->delete();
        }

        return response()->noContent();
    }
}
