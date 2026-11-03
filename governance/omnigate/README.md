# OMNIGATE — récupération réelle d'autorité / pont Git-UAC

**État : ingénierie candidate, non installée, non approuvée, non exécutée pour émission d'autorité.**

## Faits du 3 novembre 2026 sur SucceesMindset

- Dépôt réel : `yannicklabuthie-code/ECTOS-Engineering`, branche locale propre, commit `f674622f88aa36476dbf2b77b2182896df064a55`.
- `github_governance.py` de l'UAC a contrôlé le ruleset GitHub **Main**, actif, conformément au contrat Git : **PASS**, reçu SHA-256 `441ef4e3ec7cef471bf5b63ceae4032c57958b97862d6d7e9b24a98b867b659d`.
- GitHub contient le secret nommé `ECTOS_UAC_SIGNING_KEY`. Le secret `ECTOS_UAC_EVIDENCE_PUBLIC_KEYS` attendu par le handoff canonique n'était pas présent dans la liste des secrets dépôt. Aucune valeur de secret n'a été lue.
- Un fichier historique V07 `G00_HTTP_SYNTHETIC_POSITIVE_RECEIPT_V01.json` existe physiquement, 4 223 octets, SHA `64c348cdf2814ade5e2e5ad2fde2f44bb60fc895b50540985ef82e46ad849d06` : **source producteur synthétique**, pas exigences owner approuvées.
- OMNIGATE V48 attend une clé publique **Ed25519 épinglée par une autorité externe** et deux enveloppes signées. L'UAC ECTOS utilise une vérification de preuve **RSA-PKCS1-v1_5-SHA256** et son reçu de handoff **HMAC** : un PASS UAC ne remplace pas directement un PASS d'autorité QC02/QC03.

## Solution concrète proposée

1. **Conserver UAC GitHub comme preuve de provenance technique** : commit, arbre Git, approbation de règles et paquet exacts ; ne jamais lui attribuer automatiquement l'autorité métier OMNIGATE.
2. **Récupérer, puis faire approuver une version exacte des exigences et des oracles QC02**. Les fichiers candidats existants V48 et la couverture V49 servent d'entrée. L'approbation du contenu appartient à l'autorité métier/owner et ne découle pas de la simple présence de fichiers.
3. **Émettre les enveloppes d'autorité à travers un job GitHub protégé** avec auteur/émetteur contrôlé, empreintes préalablement approuvées, conservation indépendante de la clé de signature, clé privée Ed25519 uniquement dans les secrets d'environnement, clé publique et empreinte épinglées séparément par l'administrateur de confiance Windows.
4. **Provisionner la politique hôte protégée** `C:\ProgramData\ECTOS\governance\omni_trust_policy.json` via la gouvernance, avec pin public authentifié, validité et révocations. Ne jamais la dériver de l'enveloppe signée ni d'un fichier du paquet candidat.
5. **Contrôler les 22 outils et attestations individuelles** : l'enveloppe de registre seule ne prouve pas les 22 provenances individuelles ni leur adéquation. Leur statut approuvé et l'identité hôte doivent être attestés séparément par le responsable de provenance.
6. **Réutiliser le lanceur V59**, qui contrôle les références aux enveloppes puis la chaîne native V48. Le résultat producteur ne devient pas automatiquement une qualification indépendante.
7. **Confier QC06 à un qualificateur distinct**, qui émet les preuves d'exécution réelles ; MAIN arbitre ensuite l'admission.

## Prérequis de mise en œuvre (autorité, pas micro-tests)

- Le Project Owner doit approuver **le contenu exact** des exigences (ou une révision explicitement adoptée) et désigner l'émetteur ; ce n'est pas un nouveau GO de test.
- L'autorité de gouvernance doit confirmer les empreintes exactes des contenus et la clé publique avant activation. L'environnement GitHub `omnigate-governance-approval` doit contenir les variables de hash approuvées et le secret Ed25519 sous garde contrôlée. Aucun second collaborateur GitHub n'est requis par le registre UAC historique.
- L'administrateur de confiance Windows doit provisionner le pin public et les politiques protégées, sans les copier depuis le candidat.
- Le responsable de provenance doit attester les 22 outils, et l'autorité de qualification doit être distincte du producteur et de MAIN.

## Limites et sécurité

**Aucune approbation ni signature ne figure dans ce ZIP.** Ne pas déployer ce workflow avant adoption explicite des textes d'autorité compatibles par le propriétaire. La signature d'un artefact GitHub établit sa provenance, pas l'approbation métier de son contenu. Une clé auto-générée par le producteur ne peut pas valoir racine indépendante. Ne pas pousser vers GitHub, modifier les secrets, le cloud, G00 ou les règles existantes sur la seule base de ce ZIP.

La commande de signature n'est pas une commande de test à faire lancer au Project Owner : c'est un point d'exécution réservé au workflow de gouvernance après son admission.


## V61 audit de sécurité du pont (PR #22)

Le code candidat doit rester non exécutable en émission tant que les véritables objets approuvés et l'environnement protégé n'existent pas. Les vérifications supplémentaires sur la branche de revue imposent désormais : GitHub `workflow_dispatch` sur `main` protégé, cohérence exacte des chemins d'enveloppes et de la source canonique sur Windows, concordance des profils QC02/QC03, et pour chacun des 22 outils les états `TRUSTED`, `CURRENT`, `PASS`, `TRUSTED` avec identité et empreinte de provenance déclarées. Aucun de ces états déclarés ne dispense du contrôle ultérieur des **octets de preuve réels** par QC03 sur l'hôte.

Le workflow contient un contrôle préalable des trois sources approuvées et sérialise les émissions. Il reste **sans source approuvée, sans environnement protégé, sans secret Ed25519 gouverné et sans preuve de reviewer indépendant**. Aucun label `APPROVED` ne doit être appliqué aux candidats V48 par le producteur. Une approbation de la PR Git ne remplace jamais une approbation des exigences métiers ni une qualification QC06 indépendante.

**Note d'interface** : les chemins `authority_envelope_ref` doivent apparaître dans les objets exacts signés. Modifier ces champs après signature invalide l'empreinte QC02/QC03. L'administrateur de confiance provisionne le pin Ed25519 séparément du paquet; la clé privée ne doit jamais être récupérée localement par ce projet.
