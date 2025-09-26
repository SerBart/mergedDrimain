package drimer.drimain.controller;

import drimer.drimain.api.dto.*;
import drimer.drimain.service.InstructionService;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/instrukcje")
@RequiredArgsConstructor
public class InstructionController {

    private final InstructionService instructionService;

    @GetMapping
    public List<InstructionDTO> list(@RequestParam(required = false) Long maszynaId) {
        return instructionService.list(maszynaId);
    }

    @GetMapping("/{id}")
    public InstructionDTO get(@PathVariable Long id) {
        return instructionService.get(id);
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    public InstructionDTO create(@RequestBody InstructionCreateRequest req,
                                 @AuthenticationPrincipal UserDetails user) {
        String createdBy = user != null ? user.getUsername() : null;
        return instructionService.create(req, createdBy);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        instructionService.delete(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping(path = "/{id}/attachments", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('ADMIN')")
    public List<InstructionAttachmentDTO> upload(@PathVariable Long id,
                                                 @RequestPart("files") List<MultipartFile> files,
                                                 @AuthenticationPrincipal UserDetails user) {
        String createdBy = user != null ? user.getUsername() : null;
        return instructionService.upload(id, files, createdBy);
    }

    @GetMapping("/{id}/attachments")
    public List<InstructionAttachmentDTO> listAttachments(@PathVariable Long id) {
        return instructionService.listAttachments(id);
    }

    @GetMapping("/attachments/{attachmentId}/download")
    public ResponseEntity<Resource> download(@PathVariable Long attachmentId) {
        Resource res = instructionService.download(attachmentId);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + res.getFilename() + "\"")
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .body(res);
    }
}
