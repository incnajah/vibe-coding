<?php

it('serves the homepage', function () {
    $this->get('/')->assertOk();
});
