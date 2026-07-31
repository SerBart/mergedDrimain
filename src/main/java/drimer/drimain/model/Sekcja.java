package drimer.drimain.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter
@Setter
@Table(name = "sekcje", uniqueConstraints = {
        @UniqueConstraint(name = "uk_sekcje_maszyna_nazwa", columnNames = {"maszyna_id", "nazwa"})
})
public class Sekcja {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String nazwa;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "maszyna_id")
    private Maszyna maszyna;
}

