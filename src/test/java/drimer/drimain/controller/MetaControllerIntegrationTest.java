package drimer.drimain.controller;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = {
        "spring.flyway.enabled=false"
})
class MetaControllerIntegrationTest {

    @Autowired
    MockMvc mockMvc;

    @Test
    @WithMockUser(username = "admin", roles = {"ADMIN"})
    void dashboardKpi_usesDefaultSevenDayRange() throws Exception {
        mockMvc.perform(get("/api/meta/dashboard-kpi"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.zakresDni").value(7))
                .andExpect(jsonPath("$.okresOd").exists())
                .andExpect(jsonPath("$.okresDo").exists())
                .andExpect(jsonPath("$.zgloszeniaWOkresieNowe").isNumber())
                .andExpect(jsonPath("$.raportyWOkresie").isNumber())
                .andExpect(jsonPath("$.zgloszeniaTrend").isArray())
                .andExpect(jsonPath("$.raportyTrend").isArray())
                .andExpect(jsonPath("$.lastUpdated").exists());
    }

    @Test
    @WithMockUser(username = "admin", roles = {"ADMIN"})
    void dashboardKpi_acceptsCustomRange() throws Exception {
        mockMvc.perform(get("/api/meta/dashboard-kpi")
                        .param("days", "30"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.zakresDni").value(30))
                .andExpect(jsonPath("$.zgloszeniaWOkresieWToku").isNumber())
                .andExpect(jsonPath("$.zgloszeniaWOkresieZamkniete").isNumber())
                .andExpect(jsonPath("$.zgloszeniaWPoprzednimOkresie").isNumber())
                .andExpect(jsonPath("$.raportyWPoprzednimOkresie").isNumber())
                .andExpect(jsonPath("$.topTypyZgloszen").isMap());
    }

    @Test
    @WithMockUser(username = "admin", roles = {"ADMIN"})
    void dashboardKpiExport_returnsCsvPayload() throws Exception {
        mockMvc.perform(get("/api/meta/dashboard-kpi/export")
                        .param("days", "7"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith("text/csv"))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("sekcja;klucz;wartosc")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("kpi;raportyWOkresie;")));
    }

    @Test
    @WithMockUser(username = "admin", roles = {"ADMIN"})
    void dashboardKpiExportPdf_returnsPdfPayload() throws Exception {
        MvcResult result = mockMvc.perform(get("/api/meta/dashboard-kpi/export.pdf")
                        .param("days", "7"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith("application/pdf"))
                .andReturn();

        byte[] body = result.getResponse().getContentAsByteArray();
        org.junit.jupiter.api.Assertions.assertTrue(body.length > 8);
        String signature = new String(body, 0, 5, java.nio.charset.StandardCharsets.US_ASCII);
        org.junit.jupiter.api.Assertions.assertEquals("%PDF-", signature);
    }
}

