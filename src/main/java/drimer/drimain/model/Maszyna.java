package drimer.drimain.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.util.LinkedHashSet;
import java.util.Set;

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

    // Wiele sekcji przypisanych do jednej maszyny (sekcja główna zostaje w polu sekcja).
    @ManyToMany
    @JoinTable(
            name = "maszyny_sekcje",
            joinColumns = @JoinColumn(name = "maszyna_id"),
            inverseJoinColumns = @JoinColumn(name = "sekcja_id")
    )
    private Set<Sekcja> sekcje = new LinkedHashSet<>();
}