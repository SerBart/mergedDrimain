package drimer.drimain.controller;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = {
        "spring.flyway.enabled=false"
})
class RaportRestControllerIntegrationTest {

    @Autowired
    MockMvc mockMvc;

    @Test
    @WithMockUser(username = "admin", roles = {"ADMIN"})
    void createRaport_acceptsFlexibleTime_returns201() throws Exception {
        String today = java.time.LocalDate.now().toString();
        String body = "{" +
                "\"typNaprawy\":\"Test z MockMvc\"," +
                "\"opis\":\"Dodany przez test\"," +
                "\"dataNaprawy\":\"" + today + "\"," +
                "\"czasOd\":\"8:00\"," +
                "\"czasDo\":\"10:15\"" +
                "}";

        mockMvc.perform(post("/api/raporty")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").exists())
                .andExpect(jsonPath("$.typNaprawy").value("Test z MockMvc"))
                .andExpect(jsonPath("$.czasOd").value("08:00"))
                .andExpect(jsonPath("$.czasDo").value("10:15"));
    }

    @Test
    @WithMockUser(username = "admin", roles = {"ADMIN"})
    void createRaport_withInvalidTime_returns400() throws Exception {
        String today = java.time.LocalDate.now().toString();
        String body = "{" +
                "\"typNaprawy\":\"Test invalid time\"," +
                "\"opis\":\"Dodany przez test\"," +
                "\"dataNaprawy\":\"" + today + "\"," +
                "\"czasOd\":\"invalid\"" +
                "}";

        mockMvc.perform(post("/api/raporty")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isBadRequest());
    }
}
