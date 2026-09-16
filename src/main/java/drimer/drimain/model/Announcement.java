package drimer.drimain.model;

import jakarta.persistence.*;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Entity
@Table(name = "announcements")
public class Announcement {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "title", nullable = false, length = 255)
    private String title;

    @Column(name = "content", nullable = false, length = 4000)
    private String content;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by_user_id")
    private User createdBy;

    @Column(name = "active", nullable = false)
    private boolean active = true;

    @Enumerated(EnumType.STRING)
    @Column(name = "target_type", nullable = false, length = 20)
    private AnnouncementTargetType targetType = AnnouncementTargetType.ALL;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "target_dzial_id")
    private Dzial targetDzial;

    @ManyToMany
    @JoinTable(
            name = "announcement_target_users",
            joinColumns = @JoinColumn(name = "announcement_id"),
            inverseJoinColumns = @JoinColumn(name = "user_id")
    )
    private Set<User> targetUsers = new HashSet<>();

    @OneToMany(mappedBy = "announcement", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("createdAt DESC")
    private List<AnnouncementAttachment> attachments = new ArrayList<>();

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getContent() {
        return content;
    }

    public void setContent(String content) {
        this.content = content;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public User getCreatedBy() {
        return createdBy;
    }

    public void setCreatedBy(User createdBy) {
        this.createdBy = createdBy;
    }

    public boolean isActive() {
        return active;
    }

    public void setActive(boolean active) {
        this.active = active;
    }

    public AnnouncementTargetType getTargetType() {
        return targetType;
    }

    public void setTargetType(AnnouncementTargetType targetType) {
        this.targetType = targetType;
    }

    public Dzial getTargetDzial() {
        return targetDzial;
    }

    public void setTargetDzial(Dzial targetDzial) {
        this.targetDzial = targetDzial;
    }

    public Set<User> getTargetUsers() {
        return targetUsers;
    }

    public void setTargetUsers(Set<User> targetUsers) {
        this.targetUsers = targetUsers;
    }

    public List<AnnouncementAttachment> getAttachments() {
        return attachments;
    }

    public void setAttachments(List<AnnouncementAttachment> attachments) {
        this.attachments = attachments;
    }
}

