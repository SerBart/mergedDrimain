package drimer.drimain.controller;

import drimer.drimain.api.dto.DirectMessageDTO;
import drimer.drimain.api.dto.MessageContactDTO;
import drimer.drimain.api.dto.SendDirectMessageRequest;
import drimer.drimain.service.DirectMessageService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/messages")
@RequiredArgsConstructor
public class DirectMessageController {

    private final DirectMessageService directMessageService;

    @GetMapping("/contacts")
    @PreAuthorize("isAuthenticated()")
    public List<MessageContactDTO> contacts(Authentication authentication) {
        try {
            return directMessageService.getContacts(authentication);
        } catch (IllegalArgumentException ex) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, ex.getMessage(), ex);
        }
    }

    @GetMapping("/thread/{userId}")
    @PreAuthorize("isAuthenticated()")
    public List<DirectMessageDTO> thread(Authentication authentication,
                                         @PathVariable Long userId,
                                         @RequestParam(defaultValue = "100") int limit) {
        try {
            return directMessageService.getThread(authentication, userId, limit);
        } catch (IllegalArgumentException ex) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, ex.getMessage(), ex);
        }
    }

    @PostMapping
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<DirectMessageDTO> send(Authentication authentication,
                                                 @Valid @RequestBody SendDirectMessageRequest request) {
        try {
            DirectMessageDTO dto = directMessageService.send(authentication, request.getRecipientUserId(), request.getContent());
            return ResponseEntity.status(HttpStatus.CREATED).body(dto);
        } catch (IllegalArgumentException ex) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, ex.getMessage(), ex);
        }
    }

    @PostMapping("/thread/{userId}/read")
    @PreAuthorize("isAuthenticated()")
    public Map<String, Object> markRead(Authentication authentication, @PathVariable Long userId) {
        try {
            int marked = directMessageService.markThreadAsRead(authentication, userId);
            return Map.of("marked", marked);
        } catch (IllegalArgumentException ex) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, ex.getMessage(), ex);
        }
    }
}


