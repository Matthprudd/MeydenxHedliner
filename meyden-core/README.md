# MEYDEN OS — noyau de synchronisation interne (travail préparatoire)

**Statut :** code prêt pour intégration, destiné à être déployé et raccordé à la base `MEYDEN OS Core`. Cette étape respecte la consigne de regrouper les corrections avant de consommer un déploiement Vercel.

## Principe

Hedliner ne fournit aucune date, donnée de compte ni état de réservation. La ressource Hedliner sert uniquement de porte d'entrée externe vers MEYDEN OS. Le calendrier, les artistes et les dossiers sont gérés et synchronisés par MEYDEN.

## Écrans

- `modules/meyden-calendrier-booking/` : calendrier 24 mois (heure du Québec), salles, dates officielles, demandes et validations par personnel MEYDEN. Dates officielles pouvant avoir les états disponible, option, confirmé, bloqué. La base empêche les doubles réservations confirmées ou bloquées d'une même salle sur une plage horaire chevauchante.
- `modules/meyden-profils-artistes/` : répertoire partagé de fiches; écriture réservée au personnel MEYDEN; lien Hedliner éventuel = simple URL, aucune synchronisation.
- `modules/meyden-dossier-client/` : espace individuel, coordonnées, projets, suivi des demandes; chaque utilisateur ne voit que les projets et demandes dont il est propriétaire.

Les trois écrans utilisent `shared/sync.js`, Supabase JS épinglé en version `2.118.0`, et les mises à jour Postgres Realtime.

## Activation — étapes nécessaires avant mise en ligne

1. Choisir l'organisation qui détiendra le nouveau projet Supabase `meyden-os-core`. La création peut engendrer des frais et doit être autorisée après vérification du coût. **Ne pas réutiliser les projets RAP JUNGLE sans décision explicite.**
2. Créer le projet au Canada (`ca-central-1`) et appliquer `sql/001_meyden_core.sql` après revue. Exécuter les tests de vérification RLS, notamment avec deux comptes distincts.
3. Dans `shared/config.js`, inscrire uniquement l'URL du projet et sa **clé publishable**, jamais sa clé secrète/service_role.
4. Configurer Supabase Auth : URL du site et URLs de retour exactes vers les trois modules; créer/inviter les utilisateurs MEYDEN. Les liens magiques sont destinés uniquement aux comptes déjà enregistrés (`shouldCreateUser:false`).
5. Accorder les rôles `admin`, `staff`, `artist` ou `client` via table `meyden_access`. Aucun visiteur ne peut s'accorder un rôle lui-même. Ajouter explicitement le premier administrateur **depuis une session SQL privilégiée**, par exemple après avoir créé son compte Auth :

   ```sql
   insert into public.meyden_access(user_id, role, approved)
   values ('<UUID DU COMPTE AUTH>', 'admin', true);
   ```

6. Tester des changements sur deux navigateurs / appareils : les dates, fiches et dossiers se propagent après connexion; un client ne peut ni voir le dossier d'un autre ni confirmer une réservation; la déconnexion bloque les accès.
7. Après validation, intégrer les 3 écrans + `shared` au dépôt central et effectuer **un seul déploiement groupé**. La page cinématographique d'accueil reste strictement inchangée.

## Sécurité

RLS activée sur chaque table. Aucune table métier n'est exposée à `anon`. Les demandes et dossiers ont des règles de propriété; seul le personnel approuvé peut publier des artistes, salles ou dates officielles. Les fonctions de vérification de rôle sont dans le schéma privé `meyden_private`, pas dans `public`. Il ne faut jamais placer des identifiants administratifs dans les fichiers HTML/JS.

## Réserves techniques

- Les projets déjà stockés en `localStorage` **ne sont pas migrés automatiquement**. Prévoir un import après consentement et dédoublonnage.
- Le module panier Services 360° conserve actuellement sa propre sauvegarde locale. Sa migration vers la même base commune est un travail ultérieur distinct.
- La date et l'heure affichées sont celles de `America/Toronto`. Le contrôle final du changement d'heure (printemps/automne) doit être réalisé avant mise en production.
- Le statut Supabase Realtime doit être vérifié avec de vraies sessions et les réglages du projet.
- Aucun lien automatique ni API Hedliner n'est autorisé par ce code.

## Première connexion — opération administrative indispensable

Dans Supabase Dashboard → Authentication → URL Configuration, placer le Site URL
`https://meydenx-hedliner.vercel.app/` et les redirections autorisées :

- `https://meydenx-hedliner.vercel.app/modules/meyden-calendrier-booking/`
- `https://meydenx-hedliner.vercel.app/modules/meyden-profils-artistes/`
- `https://meydenx-hedliner.vercel.app/modules/meyden-dossier-client/`

Une fois connecté, le premier administrateur transmet son UUID visible dans l’écran d’attente, puis un responsable ayant l’accès privilégié au SQL Editor exécute une seule fois :

```sql
update public.meyden_access set role='admin', approved=true
where user_id='<UUID COMPTE VÉRIFIÉ>';
```

À ce moment, l’administrateur peut approuver les comptes suivants depuis le module « Mon dossier ». Le projet ne distribue jamais les privilèges admin automatiquement.

Ne pas afficher la clé service_role; seule la clé Supabase publishable figure dans `shared/config.js`.