# Mesures des anciennes sessions

Dans « Donnees », le choix initial « 24 heures » exclut les recharges plus
anciennes. Le choix « 7 jours » peut inclure les mesures du 18 septembre si
elles ont ete historisees, mais ce CSV regroupe les donnees par minute et ne
conserve pas l'identifiant de session. « Telecharger les sessions » fournit
le bilan (energie, duree, puissance), sans les points de mesure AC.

Pour obtenir les points d'une recharge precise, ouvrir « Sessions », choisir
la recharge, puis cliquer « Telecharger les mesures de cette session ». Le
CSV retourne les valeurs brutes conservees. Une colonne `association` vaut
`session_id` si le firmware a marque les mesures ou `plage_horaire` pour les
anciennes mesures sans identifiant trouvees entre le debut et la fin de la
session. Une association par horaires est indicative. Si aucune mesure n'a
ete conservee, le Hub indique explicitement qu'il n'y en a pas ; le bilan
de la session reste disponible independamment.

L'export par session requiert le code du Hub correspondant a cette mise a
jour sur le VPS. Installer le nouveau frontend sans mettre a jour le Hub
produira une reponse HTTP 404 pour ce bouton. Les exports s'ouvrent dans le
navigateur, qui peut demander les identifiants HTTP du site.
