<?php

return [
    'paths' => ['api/*'],
    'allowed_methods' => ['GET', 'POST', 'PUT', 'OPTIONS'],
    'allowed_origins' => array_values(array_filter(array_map(
        'trim', explode(',', (string) env('CORS_ALLOWED_ORIGINS', ''))
    ))),
    'allowed_origins_patterns' => [],
    'allowed_headers' => ['Accept', 'Authorization', 'Content-Type'],
    'exposed_headers' => ['X-Request-ID'],
    'max_age' => 600,
    'supports_credentials' => false,
];
