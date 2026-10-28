package com.example.monitoring.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class ApiController {

    @GetMapping("/hello")
    public Map<String, Object> hello() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "UP");
        response.put("service", "backend-service");
        response.put("message", "Heartbeat OK - Spring Boot Backend with Actuator & Prometheus");
        response.put("timestamp", Instant.now().toString());
        return response;
    }
}
