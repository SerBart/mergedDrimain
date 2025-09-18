package drimer.drimain.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter @Setter
@Table(name="parts")
public class Part {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable=false)
    private String nazwa;

    @Column(nullable=false)
    private String kod;

    private String kategoria;

    private Integer ilosc;
    private Integer minIlosc;
    private String jednostka;
}