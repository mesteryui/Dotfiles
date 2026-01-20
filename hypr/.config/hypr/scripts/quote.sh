#!/bin/bash

# Array de frases interesantes
frases=(
    "El orden es el placer de la razón; pero el desorden es la delicia de la imaginación."
    "Hazlo simple, pero significativo."
    "La elegancia es la única belleza que nunca se marchita."
    "Tu mente es el mejor software, prográmala bien."
    "Stay hungry, stay foolish."
    "Menos es más."
    "La perfección no se alcanza cuando no hay más que añadir, sino cuando ya no queda nada por quitar."
    "La claridad es el poder de los inteligentes."
    "El conocimiento es ruido si no se transforma en acción."
    "La sencillez es la máxima sofisticación."
)

# Obtener un índice aleatorio
# $RANDOM genera un número entre 0 y 32767
# % ${#frases[@]} limita ese número al tamaño del array
indice=$(( RANDOM % ${#frases[@]} ))

# Imprimir la frase
echo "<i>${frases[$indice]}</i>"
