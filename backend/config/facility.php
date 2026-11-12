<?php

return [
    'demo_password' => env('FACILITY_DEMO_PASSWORD'),
    'finding_escalation_minutes' => (int) env('FACILITY_FINDING_ESCALATION_MINUTES', 1440),
];
