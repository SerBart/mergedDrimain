package drimer.drimain.service;

import drimer.drimain.api.dto.DirectMessageDTO;
import drimer.drimain.api.dto.MessageContactDTO;
import drimer.drimain.model.DirectMessage;
import drimer.drimain.model.NotificationType;
import drimer.drimain.model.User;
import drimer.drimain.repository.DirectMessageRepository;
import drimer.drimain.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Comparator;
import java.util.List;

@Service
@RequiredArgsConstructor
public class DirectMessageService {

    private final DirectMessageRepository directMessageRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;

    @Transactional(readOnly = true)
    public List<MessageContactDTO> getContacts(Authentication authentication) {
        User me = requireUser(authentication);

        return userRepository.findAll().stream()
                .filter(u -> !u.getId().equals(me.getId()))
                .map(u -> toContactDto(me, u))
                .sorted(Comparator
                        .comparing(MessageContactDTO::getLastMessageAt, Comparator.nullsLast(Comparator.reverseOrder()))
                        .thenComparing(MessageContactDTO::getUsername, String.CASE_INSENSITIVE_ORDER))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<DirectMessageDTO> getThread(Authentication authentication, Long withUserId, int limit) {
        User me = requireUser(authentication);
        User other = requireExistingUser(withUserId);

        int safeLimit = Math.min(Math.max(limit, 1), 200);
        List<DirectMessage> messages = directMessageRepository.findThread(me.getId(), other.getId(), PageRequest.of(0, safeLimit));

        return messages.stream().map(this::toDto).toList();
    }

    @Transactional
    public DirectMessageDTO send(Authentication authentication, Long recipientUserId, String content) {
        User me = requireUser(authentication);
        User recipient = requireExistingUser(recipientUserId);

        String clean = content == null ? "" : content.trim();
        if (clean.isEmpty()) {
            throw new IllegalArgumentException("Wiadomość nie może być pusta");
        }
        if (recipient.getId().equals(me.getId())) {
            throw new IllegalArgumentException("Nie możesz wysłać wiadomości do siebie");
        }

        DirectMessage msg = new DirectMessage();
        msg.setSender(me);
        msg.setRecipient(recipient);
        msg.setContent(clean);
        msg.setCreatedAt(Instant.now());

        DirectMessage saved = directMessageRepository.save(msg);

        String preview = clean.length() > 120 ? clean.substring(0, 120) + "..." : clean;
        notificationService.createPersonalNotification(
                recipient,
                NotificationType.GENERIC,
                "Nowa wiadomość od " + me.getUsername(),
                preview,
                "/messages"
        );

        return toDto(saved);
    }

    @Transactional
    public int markThreadAsRead(Authentication authentication, Long withUserId) {
        User me = requireUser(authentication);
        User other = requireExistingUser(withUserId);

        List<DirectMessage> unread = directMessageRepository.findByRecipientAndSenderAndReadAtIsNull(me, other);
        if (unread.isEmpty()) {
            return 0;
        }

        Instant now = Instant.now();
        unread.forEach(m -> m.setReadAt(now));
        directMessageRepository.saveAll(unread);
        return unread.size();
    }

    private MessageContactDTO toContactDto(User me, User other) {
        MessageContactDTO dto = new MessageContactDTO();
        dto.setUserId(other.getId());
        dto.setUsername(other.getUsername());
        dto.setEmail(other.getEmail());
        dto.setUnreadCount(directMessageRepository.countByRecipientAndSenderAndReadAtIsNull(me, other));

        List<DirectMessage> latest = directMessageRepository.findLatestBetween(
                me.getId(),
                other.getId(),
                PageRequest.of(0, 1)
        );

        if (!latest.isEmpty()) {
            DirectMessage last = latest.get(0);
            dto.setLastMessage(last.getContent());
            dto.setLastMessageAt(last.getCreatedAt());
        }

        return dto;
    }

    private DirectMessageDTO toDto(DirectMessage msg) {
        DirectMessageDTO dto = new DirectMessageDTO();
        dto.setId(msg.getId());
        dto.setSenderId(msg.getSender().getId());
        dto.setSenderUsername(msg.getSender().getUsername());
        dto.setRecipientId(msg.getRecipient().getId());
        dto.setRecipientUsername(msg.getRecipient().getUsername());
        dto.setContent(msg.getContent());
        dto.setCreatedAt(msg.getCreatedAt());
        dto.setRead(msg.getReadAt() != null);
        return dto;
    }

    private User requireUser(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            throw new IllegalArgumentException("Brak zalogowanego użytkownika");
        }
        return userRepository.findByUsername(authentication.getName())
                .orElseThrow(() -> new IllegalArgumentException("Użytkownik nie istnieje"));
    }

    private User requireExistingUser(Long id) {
        if (id == null || id <= 0) {
            throw new IllegalArgumentException("Nieprawidłowy użytkownik");
        }
        return userRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Użytkownik nie istnieje"));
    }
}

