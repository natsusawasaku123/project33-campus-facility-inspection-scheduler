<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\Request as HttpRequest;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->redirectGuestsTo(fn (Request $request) => $request->is('api/*') ? null : '/');
        $middleware->trustProxies(
            headers: HttpRequest::HEADER_X_FORWARDED_FOR | HttpRequest::HEADER_X_FORWARDED_PROTO,
        );
        $middleware->append(\App\Http\Middleware\ApiSecurity::class);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(fn (Request $request) => $request->is('api/*') || $request->expectsJson());
        $exceptions->report(function (\Throwable $error) {
            if (request()->is('api/*')) {
                Log::channel('security')->error('security.api_exception', [
                    'request_id' => request()->attributes->get('security_request_id'),
                    'exception_type' => $error::class,
                ]);

                // Keep exception messages, SQL bindings and traces out of API logs.
                return false;
            }
        });
        $exceptions->render(function (\Throwable $error, Request $request) {
            if ($request->is('api/*')
                && (! $error instanceof HttpExceptionInterface || $error->getStatusCode() >= 500)
                && ! $error instanceof \Illuminate\Auth\AuthenticationException
                && ! $error instanceof \Illuminate\Auth\Access\AuthorizationException
                && ! $error instanceof \Illuminate\Validation\ValidationException
                && ! $error instanceof \Illuminate\Database\Eloquent\ModelNotFoundException) {
                return response()->json([
                    'message' => 'An unexpected error occurred.',
                    'request_id' => $request->attributes->get('security_request_id'),
                ], $error instanceof HttpExceptionInterface ? $error->getStatusCode() : 500);
            }
        });
    })->create();
