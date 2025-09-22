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
import org.springframework.test.context.TestPropertySource;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.WebApplicationContext;

import java.util.HashMap;
import java.util.Map;
import java.util.Set;

import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.springframework.test.web.servlet.setup.MockMvcBuilders.webAppContextSetup;

@SpringBootTest(classes = DriMainApplication.class)
@ActiveProfiles("test")
@TestPropertySource(properties = {
        // JWT secret (>=32 bajty) – wymagane przez JwtService
        "jwt.secret.plain=test-secret-key-that-is-at-least-32-characters-long-for-hmac-sha256",
        "app.jwt.access-expiration=3600000",
        "app.jwt.refresh-expiration=604800000",
        // Utwórz schemat H2 z encji i wyłącz Flyway w tym teście
        "spring.jpa.hibernate.ddl-auto=create-drop",
        "spring.flyway.enabled=false"
})
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

    private String adminToken;
    private String userToken;

    @BeforeEach
    void setUp() throws Exception {
        mockMvc = webAppContextSetup(webApplicationContext)
                .apply(springSecurity())
                .build();

        Role adminRole = roleRepository.findByName("ROLE_ADMIN")
                .orElseGet(() -> {
                    Role r = new Role();
                    r.setName("ROLE_ADMIN");
                    return roleRepository.save(r);
                });

        Role userRole = roleRepository.findByName("ROLE_USER")
                .orElseGet(() -> {
                    Role r = new Role();
                    r.setName("ROLE_USER");
                    return roleRepository.save(r);
                });

        User adminUser = new User();
        adminUser.setUsername("testadmin");
        adminUser.setPassword(passwordEncoder.encode("testpass123"));
        adminUser.setRoles(Set.of(adminRole, userRole));
        userRepository.save(adminUser);

        User regularUser = new User();
        regularUser.setUsername("testuser");
        regularUser.setPassword(passwordEncoder.encode("testpass123"));
        regularUser.setRoles(Set.of(userRole));
        userRepository.save(regularUser);

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
        Map<?, ?> authResponse = objectMapper.readValue(response, Map.class);
        return (String) authResponse.get("token");
    }

    @Test
    void shouldAllowAdminToCreateReport() throws Exception {
        Map<String, Object> reportRequest = new HashMap<>();
        reportRequest.put("typNaprawy", "Test Repair");
        reportRequest.put("opis", "Test description");

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
        Map<String, Object> reportRequest = new HashMap<>();
        reportRequest.put("typNaprawy", "Test Repair");
        reportRequest.put("opis", "Test description");

        mockMvc.perform(post("/api/raporty")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(reportRequest)))
                .andExpect(status().isForbidden());
    }

    @Test
    void shouldAllowRegularUserToReadReports() throws Exception {
        mockMvc.perform(get("/api/raporty?sort=dataNaprawy:desc")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk());
    }
}