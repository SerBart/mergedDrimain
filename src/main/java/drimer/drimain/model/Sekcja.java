package drimer.drimain.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter
@Setter
@Table(name = "sekcje", uniqueConstraints = {
        @UniqueConstraint(name = "uk_sekcje_dzial_nazwa", columnNames = {"dzial_id", "nazwa"})
})
public class Sekcja {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String nazwa;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "dzial_id", nullable = false)
    private Dzial dzial;
}

