<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

class ApiSecurity
{
    public function handle(Request $request, Closure $next): Response
    {
        if (! $request->is('api/*')) {
            return $next($request);
        }
        $requestId = (string) Str::uuid();
        $request->attributes->set('security_request_id', $requestId);
        $requireHttps = config('security.require_https') || ! app()->environment('local', 'testing');

        $response = $requireHttps && ! $request->isSecure()
            ? response()->json(['message' => 'HTTPS is required.'], 400)
            : $next($request);

        $response->headers->set('Cache-Control', 'no-store');
        $response->headers->set('X-Content-Type-Options', 'nosniff');
        $response->headers->set('Referrer-Policy', 'no-referrer');
        $response->headers->set('X-Request-ID', $requestId);
        if ($request->isSecure()) {
            $response->headers->set('Strict-Transport-Security', app()->environment('local', 'testing')
                ? 'max-age=300' : 'max-age=31536000');
        }

        // Use a static route template, never a raw URL, query, header or body.
        // Do not resolve authentication here: blocked HTTP must not inspect a token.
        $actor = $request->isSecure() || ! $requireHttps
            ? $request->user()
            : null;
        Log::channel('security')->info('security.api_request', [
            'request_id' => $requestId,
            'method' => $request->method(),
            'route' => $request->route()?->uri(),
            'status' => $response->getStatusCode(),
            'actor_id' => $actor?->id,
        ]);

        return $response;
    }
}
