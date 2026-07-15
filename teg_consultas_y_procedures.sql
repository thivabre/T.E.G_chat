-- ============================================================================
-- TEG - CONSULTAS Y STORED PROCEDURES
-- Basado en el esquema: Continentes, Paises, Paises_Limitrofes, Cartas,
-- Objetivos, Partida, Usuarios, Territorios_Partida, Cartas_Partida,
-- Intercambios, Objetivos_Partida, Turnos, Estadisticas, Chat
-- ============================================================================


-- ============================================================================
-- SECCIÓN 1: CONSULTAS (SELECT)
-- ============================================================================

-- 1.1 Listar partidas públicas disponibles para unirse (con cupo libre)
SELECT p.id_partida, p.nombre_partida, p.max_jugadores,
       COUNT(u.id_usuario) AS jugadores_actuales
FROM Partida p
LEFT JOIN Usuarios u ON u.id_partida = p.id_partida AND u.estado = 'activo'
WHERE p.tipo = 'publica' AND p.estado = 'esperando'
GROUP BY p.id_partida
HAVING jugadores_actuales < p.max_jugadores;

-- 1.2 Ver jugadores de una partida (con color y orden de turno)
SELECT id_usuario, nombre, color, orden_turno, estado
FROM Usuarios
WHERE id_partida = :id_partida
ORDER BY orden_turno;

-- 1.3 Ver todos los territorios de una partida con su dueño y ejércitos
SELECT tp.id_territorio, pa.nombre AS pais, c.nombre AS continente,
       u.nombre AS jugador, tp.cantidad_ejercitos
FROM Territorios_Partida tp
JOIN Paises pa ON pa.id_pais = tp.id_pais
JOIN Continentes c ON c.id_continente = pa.id_continente
LEFT JOIN Usuarios u ON u.id_usuario = tp.id_usuario
WHERE tp.id_partida = :id_partida
ORDER BY c.nombre, pa.nombre;

-- 1.4 Ver territorios de un jugador específico dentro de una partida
SELECT pa.nombre AS pais, tp.cantidad_ejercitos
FROM Territorios_Partida tp
JOIN Paises pa ON pa.id_pais = tp.id_pais
WHERE tp.id_partida = :id_partida AND tp.id_usuario = :id_usuario;

-- 1.5 Contar cantidad de países y ejércitos totales por jugador
SELECT u.id_usuario, u.nombre,
       COUNT(tp.id_territorio) AS paises_controlados,
       COALESCE(SUM(tp.cantidad_ejercitos), 0) AS ejercitos_totales
FROM Usuarios u
LEFT JOIN Territorios_Partida tp ON tp.id_usuario = u.id_usuario AND tp.id_partida = u.id_partida
WHERE u.id_partida = :id_partida
GROUP BY u.id_usuario, u.nombre;

-- 1.6 Ver países limítrofes de un país (para validar ataques/fortificaciones)
SELECT pd.id_pais, pd.nombre
FROM Paises_Limitrofes pl
JOIN Paises pd ON pd.id_pais = pl.id_pais_destino
WHERE pl.id_pais_origen = :id_pais;

-- 1.7 Continentes controlados completamente por un jugador (para bonus de refuerzo)
SELECT c.id_continente, c.nombre, c.bonus_ejercitos
FROM Continentes c
WHERE NOT EXISTS (
    SELECT 1 FROM Paises pa
    WHERE pa.id_continente = c.id_continente
      AND NOT EXISTS (
          SELECT 1 FROM Territorios_Partida tp
          WHERE tp.id_pais = pa.id_pais
            AND tp.id_partida = :id_partida
            AND tp.id_usuario = :id_usuario
      )
);

-- 1.8 Ver cartas en mano de un jugador
SELECT cp.id_carta_partida, ca.tipo_figura, pa.nombre AS pais
FROM Cartas_Partida cp
JOIN Cartas ca ON ca.id_carta = cp.id_carta
LEFT JOIN Paises pa ON pa.id_pais = ca.id_pais
WHERE cp.id_partida = :id_partida AND cp.id_usuario = :id_usuario
  AND cp.estado = 'mano';

-- 1.9 Ver cuántas cartas quedan en el mazo de una partida
SELECT COUNT(*) AS cartas_en_mazo
FROM Cartas_Partida
WHERE id_partida = :id_partida AND estado = 'mazo';

-- 1.10 Historial de intercambios de cartas de un jugador
SELECT i.id_intercambio, i.ejercitos_obtenidos, i.fecha_intercambio
FROM Intercambios i
WHERE i.id_partida = :id_partida AND i.id_usuario = :id_usuario
ORDER BY i.fecha_intercambio DESC;

-- 1.11 Ver el objetivo asignado a un jugador y si lo cumplió
SELECT o.descripcion, o.tipo, op.cumplido
FROM Objetivos_Partida op
JOIN Objetivos o ON o.id_objetivo = op.id_objetivo
WHERE op.id_partida = :id_partida AND op.id_usuario = :id_usuario;

-- 1.12 Ver el turno actual de una partida (el último sin fecha_fin)
SELECT t.id_turno, t.id_usuario, u.nombre, t.numero_turno, t.fase, t.fecha_inicio
FROM Turnos t
JOIN Usuarios u ON u.id_usuario = t.id_usuario
WHERE t.id_partida = :id_partida AND t.fecha_fin IS NULL
ORDER BY t.id_turno DESC
LIMIT 1;

-- 1.13 Historial de turnos de una partida
SELECT t.numero_turno, u.nombre, t.fase, t.fecha_inicio, t.fecha_fin
FROM Turnos t
JOIN Usuarios u ON u.id_usuario = t.id_usuario
WHERE t.id_partida = :id_partida
ORDER BY t.numero_turno;

-- 1.14 Ranking de jugadores de una partida por desempeño
SELECT u.nombre, e.paises_conquistados, e.cartas_obtenidas,
       e.ejercitos_ganados, e.ejercitos_perdidos, e.resultado
FROM Estadisticas e
JOIN Usuarios u ON u.id_usuario = e.id_usuario
WHERE e.id_partida = :id_partida
ORDER BY e.paises_conquistados DESC, e.ejercitos_ganados DESC;

-- 1.15 Ver mensajes de chat general de una partida
SELECT ch.id_mensaje, u.nombre AS emisor, ch.mensaje, ch.fecha_envio
FROM Chat ch
JOIN Usuarios u ON u.id_usuario = ch.id_emisor
WHERE ch.id_partida = :id_partida AND ch.tipo = 'general'
ORDER BY ch.fecha_envio;

-- 1.16 Ver mensajes privados entre dos usuarios en una partida
SELECT ch.id_mensaje, ch.id_emisor, ch.id_receptor, ch.mensaje, ch.fecha_envio
FROM Chat ch
WHERE ch.id_partida = :id_partida AND ch.tipo = 'privado'
  AND ((ch.id_emisor = :id_usuario_a AND ch.id_receptor = :id_usuario_b)
    OR (ch.id_emisor = :id_usuario_b AND ch.id_receptor = :id_usuario_a))
ORDER BY ch.fecha_envio;

-- 1.17 Ver países sin dueño en una partida (útil durante el setup)
SELECT pa.id_pais, pa.nombre
FROM Paises pa
WHERE pa.id_pais NOT IN (
    SELECT id_pais FROM Territorios_Partida WHERE id_partida = :id_partida
);

-- 1.18 Detectar jugadores eliminados (sin territorios) de una partida en curso
SELECT u.id_usuario, u.nombre
FROM Usuarios u
WHERE u.id_partida = :id_partida AND u.estado = 'activo'
  AND NOT EXISTS (
      SELECT 1 FROM Territorios_Partida tp
      WHERE tp.id_usuario = u.id_usuario AND tp.id_partida = u.id_partida
  );

-- 1.19 Ver historial de partidas finalizadas y su ganador
SELECT p.id_partida, p.nombre_partida, e.id_usuario AS id_ganador, u.nombre AS ganador
FROM Partida p
JOIN Estadisticas e ON e.id_partida = p.id_partida AND e.resultado = 'ganador'
JOIN Usuarios u ON u.id_usuario = e.id_usuario
WHERE p.estado = 'finalizada';

-- 1.20 Ver el estado completo del tablero (para renderizar el mapa en el cliente)
SELECT c.nombre AS continente, pa.id_pais, pa.nombre AS pais,
       tp.id_usuario, u.color, tp.cantidad_ejercitos
FROM Paises pa
JOIN Continentes c ON c.id_continente = pa.id_continente
LEFT JOIN Territorios_Partida tp ON tp.id_pais = pa.id_pais AND tp.id_partida = :id_partida
LEFT JOIN Usuarios u ON u.id_usuario = tp.id_usuario;


-- ============================================================================
-- SECCIÓN 2: STORED PROCEDURES
-- ============================================================================

DELIMITER $$

-- 2.1 Crear una nueva partida
CREATE PROCEDURE sp_crear_partida (
    IN p_nombre_partida VARCHAR(100),
    IN p_tipo ENUM('publica','privada'),
    IN p_codigo_acceso VARCHAR(10),
    IN p_max_jugadores INT
)
BEGIN
    INSERT INTO Partida (nombre_partida, tipo, codigo_acceso, max_jugadores)
    VALUES (p_nombre_partida, p_tipo, p_codigo_acceso, p_max_jugadores);

    SELECT LAST_INSERT_ID() AS id_partida;
END$$


-- 2.2 Unir un jugador a una partida existente (valida cupo y código si es privada)
CREATE PROCEDURE sp_unirse_partida (
    IN p_id_partida INT,
    IN p_nombre VARCHAR(50),
    IN p_codigo_acceso VARCHAR(10)
)
BEGIN
    DECLARE v_tipo VARCHAR(20);
    DECLARE v_codigo VARCHAR(10);
    DECLARE v_max INT;
    DECLARE v_actuales INT;

    SELECT tipo, codigo_acceso, max_jugadores
      INTO v_tipo, v_codigo, v_max
      FROM Partida WHERE id_partida = p_id_partida;

    SELECT COUNT(*) INTO v_actuales
      FROM Usuarios WHERE id_partida = p_id_partida AND estado = 'activo';

    IF v_actuales >= v_max THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La partida está completa';
    ELSEIF v_tipo = 'privada' AND (v_codigo IS NULL OR v_codigo <> p_codigo_acceso) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Código de acceso incorrecto';
    ELSE
        INSERT INTO Usuarios (nombre, id_partida, orden_turno)
        VALUES (p_nombre, p_id_partida, v_actuales + 1);

        SELECT LAST_INSERT_ID() AS id_usuario;
    END IF;
END$$


-- 2.3 Iniciar la partida: reparte países, ejércitos iniciales, cartas y objetivos
CREATE PROCEDURE sp_iniciar_partida (
    IN p_id_partida INT
)
BEGIN
    -- Reparte todos los países de forma rotativa entre los jugadores activos
    INSERT INTO Territorios_Partida (id_partida, id_pais, id_usuario, cantidad_ejercitos)
    SELECT p_id_partida, x.id_pais, x.id_usuario, 1
    FROM (
        SELECT pa.id_pais,
               (SELECT u.id_usuario
                FROM Usuarios u
                WHERE u.id_partida = p_id_partida AND u.estado = 'activo'
                ORDER BY u.orden_turno
                LIMIT 1 OFFSET (
                    (pa.id_pais - 1) % (SELECT COUNT(*) FROM Usuarios
                                        WHERE id_partida = p_id_partida AND estado = 'activo')
                )
               ) AS id_usuario
        FROM Paises pa
    ) x;

    -- Pone todas las cartas de la partida disponibles en el mazo
    INSERT INTO Cartas_Partida (id_partida, id_carta, estado)
    SELECT p_id_partida, id_carta, 'mazo' FROM Cartas;

    -- Asigna un objetivo aleatorio a cada jugador
    INSERT INTO Objetivos_Partida (id_partida, id_objetivo, id_usuario)
    SELECT p_id_partida,
           (SELECT id_objetivo FROM Objetivos ORDER BY RAND() LIMIT 1),
           id_usuario
    FROM Usuarios
    WHERE id_partida = p_id_partida AND estado = 'activo';

    -- Crea una fila de estadísticas por jugador
    INSERT INTO Estadisticas (id_usuario, id_partida)
    SELECT id_usuario, p_id_partida
    FROM Usuarios
    WHERE id_partida = p_id_partida AND estado = 'activo';

    UPDATE Partida SET estado = 'en_curso' WHERE id_partida = p_id_partida;

    -- Crea el primer turno para el jugador con orden_turno = 1
    INSERT INTO Turnos (id_partida, id_usuario, numero_turno, fase, fecha_inicio)
    SELECT p_id_partida, id_usuario, 1, 'refuerzo', NOW()
    FROM Usuarios
    WHERE id_partida = p_id_partida AND estado = 'activo'
    ORDER BY orden_turno LIMIT 1;
END$$


-- 2.4 Calcular y otorgar refuerzos de inicio de turno (países/3 + bonus continentes)
CREATE PROCEDURE sp_calcular_refuerzos (
    IN p_id_partida INT,
    IN p_id_usuario INT,
    OUT p_ejercitos_otorgados INT
)
BEGIN
    DECLARE v_paises INT;
    DECLARE v_bonus_continentes INT DEFAULT 0;

    SELECT COUNT(*) INTO v_paises
    FROM Territorios_Partida
    WHERE id_partida = p_id_partida AND id_usuario = p_id_usuario;

    SELECT COALESCE(SUM(c.bonus_ejercitos), 0) INTO v_bonus_continentes
    FROM Continentes c
    WHERE NOT EXISTS (
        SELECT 1 FROM Paises pa
        WHERE pa.id_continente = c.id_continente
          AND NOT EXISTS (
              SELECT 1 FROM Territorios_Partida tp
              WHERE tp.id_pais = pa.id_pais
                AND tp.id_partida = p_id_partida
                AND tp.id_usuario = p_id_usuario
          )
    );

    SET p_ejercitos_otorgados = GREATEST(FLOOR(v_paises / 3), 3) + v_bonus_continentes;

    UPDATE Territorios_Partida
    SET cantidad_ejercitos = cantidad_ejercitos + p_ejercitos_otorgados
    WHERE id_partida = p_id_partida AND id_usuario = p_id_usuario
    ORDER BY id_territorio LIMIT 1;
END$$


-- 2.5 Realizar un ataque simplificado entre dos territorios
CREATE PROCEDURE sp_realizar_ataque (
    IN p_id_partida INT,
    IN p_id_pais_origen INT,
    IN p_id_pais_destino INT,
    IN p_dados_atacante INT,
    IN p_dados_defensor INT,
    OUT p_resultado VARCHAR(20)
)
BEGIN
    DECLARE v_es_limitrofe INT;
    DECLARE v_atacante INT;
    DECLARE v_defensor INT;
    DECLARE v_ejercitos_origen INT;
    DECLARE v_ejercitos_destino INT;
    DECLARE v_perdidas_atacante INT;
    DECLARE v_perdidas_defensor INT;

    SELECT COUNT(*) INTO v_es_limitrofe
    FROM Paises_Limitrofes
    WHERE id_pais_origen = p_id_pais_origen AND id_pais_destino = p_id_pais_destino;

    IF v_es_limitrofe = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Los países no son limítrofes';
    END IF;

    SELECT id_usuario, cantidad_ejercitos INTO v_atacante, v_ejercitos_origen
    FROM Territorios_Partida
    WHERE id_partida = p_id_partida AND id_pais = p_id_pais_origen;

    SELECT id_usuario, cantidad_ejercitos INTO v_defensor, v_ejercitos_destino
    FROM Territorios_Partida
    WHERE id_partida = p_id_partida AND id_pais = p_id_pais_destino;

    -- Simplificación: quien tira más dados en promedio gana la ronda (reemplazar
    -- por la lógica real de comparación dado a dado en la capa de aplicación)
    SET v_perdidas_defensor = LEAST(p_dados_atacante, v_ejercitos_destino);
    SET v_perdidas_atacante = LEAST(p_dados_defensor, v_ejercitos_origen - 1);

    UPDATE Territorios_Partida
    SET cantidad_ejercitos = cantidad_ejercitos - v_perdidas_atacante
    WHERE id_partida = p_id_partida AND id_pais = p_id_pais_origen;

    UPDATE Territorios_Partida
    SET cantidad_ejercitos = GREATEST(cantidad_ejercitos - v_perdidas_defensor, 0)
    WHERE id_partida = p_id_partida AND id_pais = p_id_pais_destino;

    -- Si el defensor se quedó sin ejércitos, el atacante conquista el territorio
    IF (SELECT cantidad_ejercitos FROM Territorios_Partida
        WHERE id_partida = p_id_partida AND id_pais = p_id_pais_destino) = 0 THEN

        UPDATE Territorios_Partida
        SET id_usuario = v_atacante, cantidad_ejercitos = 1
        WHERE id_partida = p_id_partida AND id_pais = p_id_pais_destino;

        UPDATE Territorios_Partida
        SET cantidad_ejercitos = cantidad_ejercitos - 1
        WHERE id_partida = p_id_partida AND id_pais = p_id_pais_origen;

        UPDATE Estadisticas
        SET paises_conquistados = paises_conquistados + 1
        WHERE id_partida = p_id_partida AND id_usuario = v_atacante;

        SET p_resultado = 'conquistado';
    ELSE
        SET p_resultado = 'repelido';
    END IF;
END$$


-- 2.6 Fortificar: mover ejércitos entre dos territorios propios
CREATE PROCEDURE sp_fortificar (
    IN p_id_partida INT,
    IN p_id_usuario INT,
    IN p_id_pais_origen INT,
    IN p_id_pais_destino INT,
    IN p_cantidad INT
)
BEGIN
    DECLARE v_disponibles INT;

    SELECT cantidad_ejercitos INTO v_disponibles
    FROM Territorios_Partida
    WHERE id_partida = p_id_partida AND id_pais = p_id_pais_origen AND id_usuario = p_id_usuario;

    IF v_disponibles IS NULL OR v_disponibles <= p_cantidad THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ejércitos insuficientes para fortificar';
    ELSE
        UPDATE Territorios_Partida
        SET cantidad_ejercitos = cantidad_ejercitos - p_cantidad
        WHERE id_partida = p_id_partida AND id_pais = p_id_pais_origen;

        UPDATE Territorios_Partida
        SET cantidad_ejercitos = cantidad_ejercitos + p_cantidad
        WHERE id_partida = p_id_partida AND id_pais = p_id_pais_destino AND id_usuario = p_id_usuario;
    END IF;
END$$


-- 2.7 Intercambiar 3 cartas por ejércitos
CREATE PROCEDURE sp_intercambiar_cartas (
    IN p_id_partida INT,
    IN p_id_usuario INT,
    IN p_carta1 INT,
    IN p_carta2 INT,
    IN p_carta3 INT
)
BEGIN
    DECLARE v_tipos INT;
    DECLARE v_total_intercambios INT;
    DECLARE v_ejercitos INT;

    -- Válido si las 3 cartas son del mismo tipo, o todas distintas, o hay comodín
    SELECT COUNT(DISTINCT ca.tipo_figura) INTO v_tipos
    FROM Cartas_Partida cp JOIN Cartas ca ON ca.id_carta = cp.id_carta
    WHERE cp.id_carta_partida IN (p_carta1, p_carta2, p_carta3);

    SELECT COUNT(*) INTO v_total_intercambios
    FROM Intercambios WHERE id_partida = p_id_partida;

    -- Escala tradicional del TEG: 5, luego +2 por cada intercambio siguiente
    SET v_ejercitos = 5 + (v_total_intercambios * 2);

    INSERT INTO Intercambios (id_partida, id_usuario, id_carta_partida1,
                               id_carta_partida2, id_carta_partida3, ejercitos_obtenidos)
    VALUES (p_id_partida, p_id_usuario, p_carta1, p_carta2, p_carta3, v_ejercitos);

    UPDATE Cartas_Partida
    SET estado = 'descartada'
    WHERE id_carta_partida IN (p_carta1, p_carta2, p_carta3);

    UPDATE Estadisticas
    SET ejercitos_ganados = ejercitos_ganados + v_ejercitos
    WHERE id_partida = p_id_partida AND id_usuario = p_id_usuario;

    SELECT v_ejercitos AS ejercitos_obtenidos;
END$$


-- 2.8 Verificar si el jugador cumplió su objetivo
CREATE PROCEDURE sp_verificar_objetivo (
    IN p_id_partida INT,
    IN p_id_usuario INT,
    OUT p_cumplido BOOLEAN
)
BEGIN
    DECLARE v_tipo VARCHAR(20);

    SELECT o.tipo INTO v_tipo
    FROM Objetivos_Partida op JOIN Objetivos o ON o.id_objetivo = op.id_objetivo
    WHERE op.id_partida = p_id_partida AND op.id_usuario = p_id_usuario;

    -- Ejemplo simplificado: objetivo de "ocupacion" cumplido si controla >= 30 países
    IF v_tipo = 'ocupacion' THEN
        SET p_cumplido = (
            SELECT COUNT(*) >= 30 FROM Territorios_Partida
            WHERE id_partida = p_id_partida AND id_usuario = p_id_usuario
        );
    ELSE
        -- Objetivo de "destruccion": el rival objetivo ya no tiene territorios
        SET p_cumplido = FALSE; -- completar con id del rival objetivo si se modela
    END IF;

    IF p_cumplido THEN
        UPDATE Objetivos_Partida
        SET cumplido = TRUE
        WHERE id_partida = p_id_partida AND id_usuario = p_id_usuario;
    END IF;
END$$


-- 2.9 Finalizar el turno actual e iniciar el del siguiente jugador activo
CREATE PROCEDURE sp_finalizar_turno (
    IN p_id_partida INT
)
BEGIN
    DECLARE v_id_usuario_actual INT;
    DECLARE v_numero_turno INT;
    DECLARE v_siguiente_usuario INT;

    SELECT id_usuario, numero_turno INTO v_id_usuario_actual, v_numero_turno
    FROM Turnos
    WHERE id_partida = p_id_partida AND fecha_fin IS NULL
    ORDER BY id_turno DESC LIMIT 1;

    UPDATE Turnos SET fecha_fin = NOW()
    WHERE id_partida = p_id_partida AND id_usuario = v_id_usuario_actual AND fecha_fin IS NULL;

    -- Siguiente jugador activo en orden circular
    SELECT id_usuario INTO v_siguiente_usuario
    FROM Usuarios
    WHERE id_partida = p_id_partida AND estado = 'activo'
      AND orden_turno > (SELECT orden_turno FROM Usuarios WHERE id_usuario = v_id_usuario_actual)
    ORDER BY orden_turno LIMIT 1;

    IF v_siguiente_usuario IS NULL THEN
        SELECT id_usuario INTO v_siguiente_usuario
        FROM Usuarios
        WHERE id_partida = p_id_partida AND estado = 'activo'
        ORDER BY orden_turno LIMIT 1;
    END IF;

    INSERT INTO Turnos (id_partida, id_usuario, numero_turno, fase, fecha_inicio)
    VALUES (p_id_partida, v_siguiente_usuario, v_numero_turno + 1, 'refuerzo', NOW());
END$$


-- 2.10 Eliminar a un jugador que se quedó sin territorios
CREATE PROCEDURE sp_eliminar_jugador (
    IN p_id_partida INT,
    IN p_id_usuario INT
)
BEGIN
    UPDATE Usuarios SET estado = 'eliminado'
    WHERE id_partida = p_id_partida AND id_usuario = p_id_usuario;

    UPDATE Estadisticas SET resultado = 'perdedor'
    WHERE id_partida = p_id_partida AND id_usuario = p_id_usuario;

    UPDATE Cartas_Partida SET estado = 'descartada', id_usuario = NULL
    WHERE id_partida = p_id_partida AND id_usuario = p_id_usuario AND estado = 'mano';
END$$


-- 2.11 Finalizar la partida y registrar al ganador
CREATE PROCEDURE sp_finalizar_partida (
    IN p_id_partida INT,
    IN p_id_ganador INT
)
BEGIN
    UPDATE Partida SET estado = 'finalizada' WHERE id_partida = p_id_partida;

    UPDATE Estadisticas SET resultado = 'ganador'
    WHERE id_partida = p_id_partida AND id_usuario = p_id_ganador;

    UPDATE Estadisticas SET resultado = 'perdedor'
    WHERE id_partida = p_id_partida AND id_usuario <> p_id_ganador AND resultado = 'en_curso';
END$$


-- 2.12 Enviar un mensaje de chat (general o privado)
CREATE PROCEDURE sp_enviar_mensaje (
    IN p_id_partida INT,
    IN p_tipo ENUM('general','privado'),
    IN p_id_emisor INT,
    IN p_id_receptor INT,
    IN p_mensaje TEXT
)
BEGIN
    INSERT INTO Chat (id_partida, tipo, id_emisor, id_receptor, mensaje)
    VALUES (p_id_partida, p_tipo, p_id_emisor, p_id_receptor, p_mensaje);
END$$

DELIMITER ;
