CREATE TABLE Continentes (
    id_continente INT AUTO_INCREMENT,
    nombre VARCHAR(50) NOT NULL,
    bonus_ejercitos INT NOT NULL,
    PRIMARY KEY (id_continente)
);

CREATE TABLE Paises (
    id_pais INT AUTO_INCREMENT,
    nombre VARCHAR(50) NOT NULL,
    id_continente INT NOT NULL,
    PRIMARY KEY (id_pais),
    CONSTRAINT fk_paises_continente FOREIGN KEY (id_continente) REFERENCES Continentes(id_continente)
);

CREATE TABLE Paises_Limitrofes (
    id_pais_origen INT NOT NULL,
    id_pais_destino INT NOT NULL,
    PRIMARY KEY (id_pais_origen, id_pais_destino),
    CONSTRAINT fk_limitrofes_origen FOREIGN KEY (id_pais_origen) REFERENCES Paises(id_pais),
    CONSTRAINT fk_limitrofes_destino FOREIGN KEY (id_pais_destino) REFERENCES Paises(id_pais)
);

CREATE TABLE Cartas (
    id_carta INT AUTO_INCREMENT,
    id_pais INT,
    tipo_figura ENUM('soldado','caballo','canon','comodin') NOT NULL,
    PRIMARY KEY (id_carta),
    CONSTRAINT fk_cartas_pais FOREIGN KEY (id_pais) REFERENCES Paises(id_pais)
);

CREATE TABLE Objetivos (
    id_objetivo INT AUTO_INCREMENT,
    descripcion VARCHAR(255) NOT NULL,
    tipo ENUM('destruccion','ocupacion') NOT NULL,
    PRIMARY KEY (id_objetivo)
);

CREATE TABLE Partida (
    id_partida INT AUTO_INCREMENT,
    nombre_partida VARCHAR(100) NOT NULL,
    tipo ENUM('publica','privada') NOT NULL,
    codigo_acceso VARCHAR(10),
    estado ENUM('esperando','en_curso','finalizada') NOT NULL DEFAULT 'esperando',
    max_jugadores INT NOT NULL DEFAULT 6,
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_partida)
);

CREATE TABLE Usuarios (
    id_usuario INT AUTO_INCREMENT,
    nombre VARCHAR(50) NOT NULL,
    id_partida INT NOT NULL,
    color VARCHAR(20),
    orden_turno INT,
    fecha_union DATETIME DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('activo','eliminado','desconectado') NOT NULL DEFAULT 'activo',
    PRIMARY KEY (id_usuario),
    CONSTRAINT fk_usuarios_partida FOREIGN KEY (id_partida) REFERENCES Partida(id_partida)
);

CREATE TABLE Territorios_Partida (
    id_territorio INT AUTO_INCREMENT,
    id_partida INT NOT NULL,
    id_pais INT NOT NULL,
    id_usuario INT,
    cantidad_ejercitos INT NOT NULL DEFAULT 0,
    PRIMARY KEY (id_territorio),
    CONSTRAINT uq_territorio_partida_pais UNIQUE (id_partida, id_pais),
    CONSTRAINT fk_territorios_partida FOREIGN KEY (id_partida) REFERENCES Partida(id_partida),
    CONSTRAINT fk_territorios_pais FOREIGN KEY (id_pais) REFERENCES Paises(id_pais),
    CONSTRAINT fk_territorios_usuario FOREIGN KEY (id_usuario) REFERENCES Usuarios(id_usuario)
);

CREATE TABLE Cartas_Partida (
    id_carta_partida INT AUTO_INCREMENT,
    id_partida INT NOT NULL,
    id_carta INT NOT NULL,
    id_usuario INT,
    estado ENUM('mazo','mano','descartada') NOT NULL DEFAULT 'mazo',
    PRIMARY KEY (id_carta_partida),
    CONSTRAINT uq_carta_partida UNIQUE (id_partida, id_carta),
    CONSTRAINT fk_cartaspartida_partida FOREIGN KEY (id_partida) REFERENCES Partida(id_partida),
    CONSTRAINT fk_cartaspartida_carta FOREIGN KEY (id_carta) REFERENCES Cartas(id_carta),
    CONSTRAINT fk_cartaspartida_usuario FOREIGN KEY (id_usuario) REFERENCES Usuarios(id_usuario)
);

CREATE TABLE Intercambios (
    id_intercambio INT AUTO_INCREMENT,
    id_partida INT NOT NULL,
    id_usuario INT NOT NULL,
    id_carta_partida1 INT NOT NULL,
    id_carta_partida2 INT NOT NULL,
    id_carta_partida3 INT NOT NULL,
    ejercitos_obtenidos INT NOT NULL,
    fecha_intercambio DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_intercambio),
    CONSTRAINT fk_intercambios_partida FOREIGN KEY (id_partida) REFERENCES Partida(id_partida),
    CONSTRAINT fk_intercambios_usuario FOREIGN KEY (id_usuario) REFERENCES Usuarios(id_usuario),
    CONSTRAINT fk_intercambios_carta1 FOREIGN KEY (id_carta_partida1) REFERENCES Cartas_Partida(id_carta_partida),
    CONSTRAINT fk_intercambios_carta2 FOREIGN KEY (id_carta_partida2) REFERENCES Cartas_Partida(id_carta_partida),
    CONSTRAINT fk_intercambios_carta3 FOREIGN KEY (id_carta_partida3) REFERENCES Cartas_Partida(id_carta_partida)
);

CREATE TABLE Objetivos_Partida (
    id_objetivo_partida INT AUTO_INCREMENT,
    id_partida INT NOT NULL,
    id_objetivo INT NOT NULL,
    id_usuario INT NOT NULL,
    cumplido BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (id_objetivo_partida),
    CONSTRAINT uq_objetivo_partida_usuario UNIQUE (id_partida, id_usuario),
    CONSTRAINT fk_objetivospartida_partida FOREIGN KEY (id_partida) REFERENCES Partida(id_partida),
    CONSTRAINT fk_objetivospartida_objetivo FOREIGN KEY (id_objetivo) REFERENCES Objetivos(id_objetivo),
    CONSTRAINT fk_objetivospartida_usuario FOREIGN KEY (id_usuario) REFERENCES Usuarios(id_usuario)
);

CREATE TABLE Turnos (
    id_turno INT AUTO_INCREMENT,
    id_partida INT NOT NULL,
    id_usuario INT NOT NULL,
    numero_turno INT NOT NULL,
    fase ENUM('refuerzo','ataque','fortificacion') NOT NULL,
    fecha_inicio DATETIME NOT NULL,
    fecha_fin DATETIME,
    PRIMARY KEY (id_turno),
    CONSTRAINT fk_turnos_partida FOREIGN KEY (id_partida) REFERENCES Partida(id_partida),
    CONSTRAINT fk_turnos_usuario FOREIGN KEY (id_usuario) REFERENCES Usuarios(id_usuario)
);

CREATE TABLE Estadisticas (
    id_estadistica INT AUTO_INCREMENT,
    id_usuario INT NOT NULL,
    id_partida INT NOT NULL,
    paises_conquistados INT NOT NULL DEFAULT 0,
    cartas_obtenidas INT NOT NULL DEFAULT 0,
    ejercitos_ganados INT NOT NULL DEFAULT 0,
    ejercitos_perdidos INT NOT NULL DEFAULT 0,
    resultado ENUM('ganador','perdedor','en_curso') NOT NULL DEFAULT 'en_curso',
    PRIMARY KEY (id_estadistica),
    CONSTRAINT uq_estadistica_usuario_partida UNIQUE (id_usuario, id_partida),
    CONSTRAINT fk_estadisticas_usuario FOREIGN KEY (id_usuario) REFERENCES Usuarios(id_usuario),
    CONSTRAINT fk_estadisticas_partida FOREIGN KEY (id_partida) REFERENCES Partida(id_partida)
);

CREATE TABLE Chat (
    id_mensaje INT AUTO_INCREMENT,
    id_partida INT NOT NULL,
    tipo ENUM('general','privado') NOT NULL,
    id_emisor INT NOT NULL,
    id_receptor INT,
    mensaje TEXT NOT NULL,
    fecha_envio DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_mensaje),
    CONSTRAINT fk_chat_partida FOREIGN KEY (id_partida) REFERENCES Partida(id_partida),
    CONSTRAINT fk_chat_emisor FOREIGN KEY (id_emisor) REFERENCES Usuarios(id_usuario),
    CONSTRAINT fk_chat_receptor FOREIGN KEY (id_receptor) REFERENCES Usuarios(id_usuario)
);
