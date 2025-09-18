package drimer.drimain.controller;

import drimer.drimain.api.dto.AttachmentDTO;
import drimer.drimain.api.dto.AttachmentUploadResponse;
import drimer.drimain.service.AttachmentService;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequiredArgsConstructor
public class AttachmentController {

    private final AttachmentService attachmentService;

    @PostMapping("/api/zgloszenia/{id}/attachments")
    @ResponseStatus(HttpStatus.CREATED)
    public AttachmentUploadResponse uploadAttachments(
            @PathVariable Long id,
            @RequestParam("files") List<MultipartFile> files,
            Authentication authentication) {
        
        String createdBy = authentication != null ? authentication.getName() : null;
        List<AttachmentDTO> attachments = attachmentService.uploadAttachments(id, files, createdBy);
        
        return new AttachmentUploadResponse(
                attachments,
                "Successfully uploaded " + attachments.size() + " file(s)"
        );
    }

    @GetMapping("/api/zgloszenia/{id}/attachments")
    public List<AttachmentDTO> listAttachments(@PathVariable Long id) {
        return attachmentService.listAttachments(id);
    }

    @GetMapping("/api/attachments/{attachmentId}/download")
    public ResponseEntity<Resource> downloadAttachment(@PathVariable Long attachmentId) {
        Resource resource = attachmentService.downloadAttachment(attachmentId);
        AttachmentDTO attachmentInfo = attachmentService.getAttachmentInfo(attachmentId);

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, 
                        "attachment; filename=\"" + attachmentInfo.getOriginalFilename() + "\"")
                .header(HttpHeaders.CONTENT_TYPE, attachmentInfo.getContentType())
                .body(resource);
    }

    @DeleteMapping("/api/attachments/{attachmentId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteAttachment(@PathVariable Long attachmentId) {
        attachmentService.deleteAttachment(attachmentId);
    }
}