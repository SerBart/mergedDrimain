package drimer.drimain.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import drimer.drimain.DriMainApplication;
import drimer.drimain.model.Role;
import drimer.drimain.model.User;
import drimer.drimain.repository.RoleRepository;
import drimer.drimain.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.Map;
import java.util.Set;

import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.springframework.test.web.servlet.setup.MockMvcBuilders.webAppContextSetup;
import org.springframework.web.context.WebApplicationContext;

@SpringBootTest(classes = DriMainApplication.class)
@ActiveProfiles("test")
@Transactional
class RefreshTokenIntegrationTest {

    private MockMvc mockMvc;

    @Autowired
    private WebApplicationContext webApplicationContext;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    private User testUser;
    private final String testUsername = "testuser";
    private final String testPassword = "testpass123";

    @BeforeEach
    void setUp() {
        // Set up MockMvc with Spring Security
        mockMvc = webAppContextSetup(webApplicationContext)
                .apply(springSecurity())
                .build();

        // Create test user with role
        Role userRole = roleRepository.findByName("ROLE_USER")
                .orElseGet(() -> {
                    Role role = new Role();
                    role.setName("ROLE_USER");
                    return roleRepository.save(role);
                });

        testUser = new User();
        testUser.setUsername(testUsername);
        testUser.setPassword(passwordEncoder.encode(testPassword));
        testUser.setRoles(Set.of(userRole));
        userRepository.save(testUser);
    }

    @Test
    void shouldLoginAndReceiveRefreshToken() throws Exception {
        // Given
        Map<String, String> loginRequest = new HashMap<>();
        loginRequest.put("username", testUsername);
        loginRequest.put("password", testPassword);

        // When & Then
        MvcResult result = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").exists())
                .andExpect(jsonPath("$.refreshToken").exists())
                .andReturn();

        String response = result.getResponse().getContentAsString();
        Map<String, String> authResponse = objectMapper.readValue(response, Map.class);
        
        // Verify both tokens are present
        assert authResponse.get("token") != null;
        assert authResponse.get("refreshToken") != null;
    }

    @Test
    void shouldRefreshAccessTokenWithValidRefreshToken() throws Exception {
        // Given - Login to get refresh token
        Map<String, String> loginRequest = new HashMap<>();
        loginRequest.put("username", testUsername);
        loginRequest.put("password", testPassword);

        MvcResult loginResult = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk())
                .andReturn();

        String loginResponse = loginResult.getResponse().getContentAsString();
        Map<String, String> authResponse = objectMapper.readValue(loginResponse, Map.class);
        String refreshToken = authResponse.get("refreshToken");

        // When - Use refresh token to get new access token
        Map<String, String> refreshRequest = new HashMap<>();
        refreshRequest.put("refreshToken", refreshToken);

        // Then
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(refreshRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").exists())
                .andExpect(jsonPath("$.refreshToken").value(refreshToken)); // Same refresh token returned
    }

    @Test
    void shouldRejectInvalidRefreshToken() throws Exception {
        // Given
        Map<String, String> refreshRequest = new HashMap<>();
        refreshRequest.put("refreshToken", "invalid-token");

        // When & Then
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(refreshRequest)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void shouldRejectEmptyRefreshToken() throws Exception {
        // Given
        Map<String, String> refreshRequest = new HashMap<>();
        refreshRequest.put("refreshToken", "");

        // When & Then
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(refreshRequest)))
                .andExpect(status().isBadRequest());
    }
}