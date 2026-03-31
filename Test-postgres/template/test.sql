CREATE TABLE fonction (
    id_fonction SERIAL PRIMARY KEY,
    libelle VARCHAR(50) NOT NULL UNIQUE
);


CREATE TABLE adresse (
    id_adresse SERIAL PRIMARY KEY,
    numero VARCHAR(10),
    rue VARCHAR(100),
    code_postal VARCHAR(10),
    ville VARCHAR(100),
    pays VARCHAR(100) DEFAULT 'France'
);


CREATE TABLE utilisateur (
    id_utilisateur SERIAL PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    prenom VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    mot_de_passe VARCHAR(255) NOT NULL,
    telephone VARCHAR(20),

    id_adresse INT REFERENCES adresse(id_adresse) ON DELETE SET NULL,
    id_fonction INT NOT NULL REFERENCES fonction(id_fonction) ON DELETE RESTRICT,

    date_creation TIMESTAMP DEFAULT NOW()
);


INSERT INTO fonction (libelle) VALUES
('etudiant'),
('formateur'),
('administrateur');

-- Ajouter une adresse
INSERT INTO adresse (numero, rue, code_postal, ville)
VALUES ('12', 'Rue des Fleurs', '06000', 'Nice')
RETURNING id_adresse;

create extension if not exists pgcrypto;

-- Ajouter un utilisateur
INSERT INTO utilisateur (nom, prenom, email, mot_de_passe, telephone, id_adresse, id_fonction)
VALUES (
    'DANIEL',
    'Kevin',
    'kevin.daniel@example.com',
    crypt('monmotdepasse', gen_salt('bf')),
    '0601020304',
    2,   -- id_adresse
    2    -- id_fonction (1 = étudiant)
);




