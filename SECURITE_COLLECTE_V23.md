# MEYDEN Ecosystem OS — collecte sécurisée (travail préparatoire)
## Statut
**NON ACTIVÉ EN PRODUCTION.** Cette branche ne configure ni base, ni API, ni collecte distante.
Le site public actuel utilise encore des formulaires et stockage navigateur; ne pas présenter comme portail sécurisé pour données sensibles.
## Architecture prévue
1. Supabase **dédié à MEYDEN**, distinct de `rap-jungle-core`.
2. Fonction serveur HTTPS unique `POST /api/requests` : HTTPS, vérification stricte JSON et champs permis, taille limitée, anti-robots (vérification côté serveur), limitation du débit par IP et identité, clé d'idempotence, journal sans PII et réponses d'erreur génériques.
3. Aucune clef `service_role` publique. RLS activée; aucune politique anon/authenticated directe.
4. Source app explicitement `os | admin | incubation | services360`; identité client non déduite d'un simple identifiant fourni par le navigateur.
5. Accès back-office exclusivement pour personnel MEYDEN authentifié et autorisé, avec journal d'accès; état `contrat` impossible à modifier par le visiteur.
6. Protection XSS : rendu texte avec `textContent` ou encodage contexte approprié, jamais `innerHTML` avec valeurs clients brutes.
7. Avis préalable à la collecte, politique de confidentialité publiée sur les quatre domaines, responsable identifié, finalités et tiers, durée de conservation à fixer, mécanismes d'accès / rectification / suppression.
8. Évaluation des facteurs relatifs à la vie privée (EFVP) de cette refonte et de tout transfert hors Québec avant données réelles.
9. Tests avec données fictives : autorisation, doublons, injections, CSRF, rétention, export, révocation, récupération en cas de panne.
10. Migration des formulaires anciens seulement après validation et possibilité de retour arrière.
## Décisions non résolues
- Choisir et créer / autoriser le projet Supabase dédié; ne pas utiliser les bases Rap Jungle.
- Identifier responsable confidentialité et adresse de contact publique.
- Déterminer rétention et conditions commerciales + avis juridique révisés.
- Déterminer hébergement et fournisseurs (Vercel, Supabase, messagerie) et EFVP selon transferts.
## Livrables
- `database/meyden_secure_submissions.sql` : migration de départ, **non appliquée**.
- Aucun formulaire réel ou paiement n'est connecté à cette migration.
