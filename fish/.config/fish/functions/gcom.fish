function gcom --description="git commit with AI"
    git commit -am $(gemini -p "Eres un desarrollador con muchos años de experiencia quiero que crees un mensaje corto para un commit en git en base a este diff $(git diff -P)")
end
