package drimer.drimain.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter @Setter
@Table(name="maszyny")
public class Maszyna {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String nazwa;

    @ManyToOne
    private Dzial dzial;

    @ManyToOne
    @JoinColumn(name = "sekcja_id")
    private drimer.drimain.model.Sekcja sekcja;
}