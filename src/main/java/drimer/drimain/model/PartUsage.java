package drimer.drimain.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter @Setter
@Table(name="part_usages")
public class PartUsage {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    private Part part;

    @ManyToOne(optional = false)
    private Raport raport;

    private Integer ilosc;
}