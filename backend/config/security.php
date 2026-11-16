<?php

return [
    'require_https' => (bool) env('SECURITY_REQUIRE_HTTPS', true),
    'trusted_proxies' => array_values(array_filter(array_map(
        'trim', explode(',', (string) env('TRUSTED_PROXIES', ''))
    ))),
];
