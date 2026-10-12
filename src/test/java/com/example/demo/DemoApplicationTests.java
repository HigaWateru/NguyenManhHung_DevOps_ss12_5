package com.example.demo;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest
class DemoApplicationTests {

    @Test
    void contextLoads() {
        // Kiểm tra Spring Context nạp thành công
        assertTrue(true, "Context loads successfully");
    }

    @Test
    void sampleUnitTest() {
        // Bài test đơn vị cơ bản
        int expected = 10;
        int actual = 5 + 5;
        org.junit.jupiter.api.Assertions.assertEquals(expected, actual, "Math calculation should match");
    }
}
