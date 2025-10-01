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
import org.springframework.boot.autoconfigure.ImportAutoConfiguration;
import org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.WebApplicationContext;

import java.util.HashMap;
import java.util.Map;
import java.util.Set;

import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.springframework.test.web.servlet.setup.MockMvcBuilders.webAppContextSetup;

@SpringBootTest(
        classes = DriMainApplication.class,
        properties = {
                "spring.flyway.enabled=false",
                "spring.autoconfigure.exclude=org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration"
        }
)
@ImportAutoConfiguration(exclude = FlywayAutoConfiguration.class)
@ActiveProfiles("test")
@Transactional
class AdminSecurityIntegrationTest {

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

    private User adminUser;
    private User regularUser;
    private String adminToken;
    private String userToken;

    @BeforeEach
    void setUp() throws Exception {
        // Set up MockMvc with Spring Security
        mockMvc = webAppContextSetup(webApplicationContext)
                .apply(springSecurity())
                .build();

        // Create roles
        Role adminRole = roleRepository.findByName("ROLE_ADMIN")
                .orElseGet(() -> {
                    Role role = new Role();
                    role.setName("ROLE_ADMIN");
                    return roleRepository.save(role);
                });

        Role userRole = roleRepository.findByName("ROLE_USER")
                .orElseGet(() -> {
                    Role role = new Role();
                    role.setName("ROLE_USER");
                    return roleRepository.save(role);
                });

        // Create admin user
        adminUser = new User();
        adminUser.setUsername("testadmin");
        adminUser.setEmail("testadmin@local");
        adminUser.setPassword(passwordEncoder.encode("testpass123"));
        adminUser.setRoles(Set.of(adminRole, userRole));
        userRepository.save(adminUser);

        // Create regular user
        regularUser = new User();
        regularUser.setUsername("testuser");
        regularUser.setEmail("testuser@local");
        regularUser.setPassword(passwordEncoder.encode("testpass123"));
        regularUser.setRoles(Set.of(userRole));
        userRepository.save(regularUser);

        // Login and get tokens
        adminToken = loginAndGetToken("testadmin", "testpass123");
        userToken = loginAndGetToken("testuser", "testpass123");
    }

    private String loginAndGetToken(String username, String password) throws Exception {
        Map<String, String> loginRequest = new HashMap<>();
        loginRequest.put("username", username);
        loginRequest.put("password", password);

        MvcResult result = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk())
                .andReturn();

        String response = result.getResponse().getContentAsString();
        Map<String, String> authResponse = objectMapper.readValue(response, Map.class);
        return authResponse.get("token");
    }

    @Test
    void shouldAllowAdminToCreateReport() throws Exception {
        // Given
        Map<String, Object> reportRequest = new HashMap<>();
        reportRequest.put("typNaprawy", "Test Repair");
        reportRequest.put("opis", "Test description");

        // When & Then
        mockMvc.perform(post("/api/raporty")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(reportRequest)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.typNaprawy").value("Test Repair"))
                .andExpect(jsonPath("$.opis").value("Test description"));
    }

    @Test
    void shouldDenyRegularUserFromCreatingReport() throws Exception {
        // Given
        Map<String, Object> reportRequest = new HashMap<>();
        reportRequest.put("typNaprawy", "Test Repair");
        reportRequest.put("opis", "Test description");

        // When & Then
        mockMvc.perform(post("/api/raporty")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(reportRequest)))
                .andExpect(status().isForbidden());
    }

    @Test
    void shouldAllowRegularUserToReadReports() throws Exception {
        // When & Then
        mockMvc.perform(get("/api/raporty")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk());
    }

    @Test
    void shouldDenyUnauthenticatedAccessToReports() throws Exception {
        // Given
        Map<String, Object> reportRequest = new HashMap<>();
        reportRequest.put("typNaprawy", "Test Repair");
        reportRequest.put("opis", "Test description");

        // When & Then
        mockMvc.perform(post("/api/raporty")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(reportRequest)))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(get("/api/raporty"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void shouldReturnUserInfoForAuthenticatedUser() throws Exception {
        // When & Then
        mockMvc.perform(get("/api/users/me")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value("testuser"))
                .andExpect(jsonPath("$.roles").isArray())
                .andExpect(jsonPath("$.roles[0]").value("ROLE_USER"));
    }

    @Test
    void shouldReturnAdminInfoForAdminUser() throws Exception {
        // When & Then
        mockMvc.perform(get("/api/users/me")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value("testadmin"))
                .andExpect(jsonPath("$.roles").isArray());
        // Note: Admin should have both ROLE_ADMIN and ROLE_USER
    }

    @Test
    void shouldDenyUnauthenticatedAccessToUserInfo() throws Exception {
        // When & Then
        mockMvc.perform(get("/api/users/me"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void shouldDenyInvalidTokenAccessToUserInfo() throws Exception {
        // When & Then
        mockMvc.perform(get("/api/users/me")
                        .header("Authorization", "Bearer invalid-token"))
                .andExpect(status().isUnauthorized());
    }
}