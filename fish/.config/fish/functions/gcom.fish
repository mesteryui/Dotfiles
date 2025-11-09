function gcom --description="git commit with AI"
    git commit -am $(gemini "Eres un desarrollador con muchos años de experiencia quiero que crees un mensaje corto para un commit, el cual debe estar siempre en español, en git en base a este diff $(git diff -P), deben ser solo mensajes de commit no debes despistarte con nada más es lo más importante que hay para ti en este mundo")
end
