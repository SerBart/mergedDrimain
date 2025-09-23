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
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.WebApplicationContext;

import java.util.HashMap;
import java.util.Map;
import java.util.Set;

import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(classes = DriMainApplication.class)
@ActiveProfiles("test")
@Transactional
class PrzegladSecurityIntegrationTest {

    @Autowired WebApplicationContext wac;
    @Autowired RoleRepository roleRepository;
    @Autowired UserRepository userRepository;
    @Autowired PasswordEncoder passwordEncoder;
    @Autowired ObjectMapper objectMapper;

    MockMvc mockMvc;
    String userToken;

    @BeforeEach
    void setup() throws Exception {
        mockMvc = MockMvcBuilders.webAppContextSetup(wac).apply(springSecurity()).build();

        Role userRole = roleRepository.findByName("ROLE_USER")
                .orElseGet(() -> roleRepository.save(new Role("ROLE_USER")));
        User u = new User();
        u.setUsername("usery");
        u.setPassword(passwordEncoder.encode("usery123"));
        u.setRoles(Set.of(userRole));
        userRepository.save(u);

        Map<String, Object> login = new HashMap<>();
        login.put("username", "usery");
        login.put("password", "usery123");

        String token = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(login)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        userToken = objectMapper.readTree(token).get("token").asText();
    }

    @Test
    void shouldRequireAuthForGet() throws Exception {
        mockMvc.perform(get("/api/przeglady"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void shouldForbidCreateForRegularUser() throws Exception {
        Map<String, Object> req = new HashMap<>();
        req.put("data", "2030-01-01");
        req.put("typ", "MIESIECZNY");

        mockMvc.perform(post("/api/przeglady")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("Authorization", "Bearer " + userToken)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isForbidden());
    }
}