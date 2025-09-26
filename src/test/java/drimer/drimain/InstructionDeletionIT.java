package drimer.drimain;

import drimer.drimain.config.AttachmentStorageConfig;
import drimer.drimain.model.Instruction;
import drimer.drimain.model.InstructionAttachment;
import drimer.drimain.model.Maszyna;
import drimer.drimain.repository.InstructionAttachmentRepository;
import drimer.drimain.repository.InstructionRepository;
import drimer.drimain.repository.MaszynaRepository;
import drimer.drimain.service.InstructionService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;

import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@TestPropertySource(properties = {
        "app.attachments.base-path=target/test-uploads"
})
public class InstructionDeletionIT {

    @Autowired InstructionRepository instructionRepository;
    @Autowired InstructionAttachmentRepository attachmentRepository;
    @Autowired MaszynaRepository maszynaRepository;
    @Autowired InstructionService instructionService;
    @Autowired AttachmentStorageConfig storageConfig;

    @BeforeEach
    void setupDir() throws Exception {
        Path base = Path.of(storageConfig.getBasePath());
        Files.createDirectories(base);
    }

    @Test
    void deleteInstruction_removesAttachmentsAndFile() throws Exception {
        // given: maszyna
        Maszyna m = new Maszyna();
        m.setNazwa("Test Maszyna");
        m = maszynaRepository.save(m);

        // and: instruction
        Instruction ins = new Instruction();
        ins.setTitle("T");
        ins.setDescription("D");
        ins.setMaszyna(m);
        ins.setCreatedAt(LocalDateTime.now());
        ins = instructionRepository.save(ins);

        // and: attachment file on disk
        String stored = "test-file.bin";
        Path file = Path.of(storageConfig.getBasePath(), stored);
        Files.writeString(file, "data");
        assertThat(Files.exists(file)).isTrue();

        // and: attachment entity
        InstructionAttachment a = new InstructionAttachment();
        a.setInstruction(ins);
        a.setOriginalFilename("orig.bin");
        a.setStoredFilename(stored);
        a.setContentType("application/octet-stream");
        a.setFileSize(4L);
        a.setCreatedBy("test");
        a = attachmentRepository.save(a);

        // sanity
        assertThat(instructionRepository.findById(ins.getId())).isPresent();
        assertThat(attachmentRepository.findById(a.getId())).isPresent();

        // when
        instructionService.delete(ins.getId());

        // then
        assertThat(instructionRepository.findById(ins.getId())).isNotPresent();
        assertThat(attachmentRepository.findById(a.getId())).isNotPresent();
        assertThat(Files.exists(file)).isFalse();
    }
}

