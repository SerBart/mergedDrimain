package drimer.drimain.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import drimer.drimain.model.Dzial;
import drimer.drimain.model.Sekcja;
import drimer.drimain.repository.DzialRepository;
import drimer.drimain.repository.SekcjaRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@TestPropertySource(properties = {
        "spring.flyway.enabled=false",
        "spring.autoconfigure.exclude=org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration"
})
class AdminMaszynaIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private DzialRepository dzialRepository;

    @Autowired
    private SekcjaRepository sekcjaRepository;

    private Dzial dzial;
    private Sekcja sekcja;

    @BeforeEach
    void setUp() {
        dzial = new Dzial();
        dzial.setNazwa("UTR-" + UUID.randomUUID());
        dzial = dzialRepository.save(dzial);

        sekcja = new Sekcja();
        sekcja.setNazwa("Sekcja A-" + UUID.randomUUID());
        sekcja.setDzial(dzial);
        sekcja = sekcjaRepository.save(sekcja);
    }

    @Test
    @WithMockUser(username = "admin", roles = {"ADMIN"})
    void shouldCreateMaszynaWithSekcjaAndReturn201() throws Exception {
        Map<String, Object> req = new HashMap<>();
        req.put("nazwa", "Maszyna testowa");
        req.put("sekcjaIds", List.of(sekcja.getId()));

        mockMvc.perform(post("/api/admin/maszyny")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").exists())
                .andExpect(jsonPath("$.nazwa").value("Maszyna testowa"))
                .andExpect(jsonPath("$.sekcja.id").value(sekcja.getId()));
    }

    @Test
    @WithMockUser(username = "admin", roles = {"ADMIN"})
    void shouldReturn400WhenSekcjaDoesNotExist() throws Exception {
        Map<String, Object> req = new HashMap<>();
        req.put("nazwa", "Maszyna z bledna sekcja");
        req.put("sekcjaIds", List.of(999999L));

        mockMvc.perform(post("/api/admin/maszyny")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isBadRequest());
    }
}
