# Plan de lucru NearPlay

Data de pornire: **6 noiembrie 2026**

Scopul este să stabilizăm și să finisăm produsul înainte să investim serios în promovare. Ordinea de lucru este:

1. testare completă pe două telefoane;
2. repararea problemelor de sesiune și conectivitate;
3. îmbunătățirea jocurilor și a UI-ului;
4. tutoriale pentru fiecare joc;
5. suport pentru versiuni iOS mai vechi;
6. verificarea achizițiilor și pregătirea unei versiuni noi;
7. optimizarea paginii App Store;
8. conținut și campanii de marketing.

---

## 0. Păstrăm o versiune stabilă de referință

- [ ] Notăm versiunea publică actuală și buildul folosit.
- [ ] Păstrăm codul versiunii publice într-un tag sau branch separat.
- [ ] Creăm un branch nou pentru următoarea actualizare.
- [ ] Instalăm același build de test pe iPhone 18 Pro și iPhone 15.
- [ ] Verificăm că ambele telefoane au Bluetooth activ și permisiunile NearPlay acordate.
- [ ] Pregătim screen recording pe ambele telefoane.
- [ ] Deschidem un singur document în care notăm toate problemele găsite.
- [ ] Nu modificăm jocurile în timpul primei treceri, exceptând un bug care blochează complet continuarea testării.

Rezultat: avem o bază stabilă și putem compara orice modificare cu versiunea publică.

---

## 1. Test rapid al conexiunii dintre telefoane

- [ ] Lansăm NearPlay simultan pe ambele telefoane.
- [ ] Telefonul A creează un lobby.
- [ ] Telefonul B caută și se conectează.
- [ ] Verificăm că numele și rolurile jucătorilor sunt corecte.
- [ ] Ieșim normal din lobby și verificăm că ambele telefoane rămân în aplicație.
- [ ] Repetăm cu telefonul B ca host.
- [ ] Punem un telefon în background timp de 10–15 secunde și revenim.
- [ ] Blocăm și deblocăm ecranul unui telefon.
- [ ] Oprim Bluetooth pentru câteva secunde și observăm mesajul afișat.
- [ ] Repornim Bluetooth și verificăm dacă utilizatorul poate intra din nou într-un lobby.

Rezultat: știm dacă transportul Bluetooth este stabil înainte să testăm fiecare joc.

---

## 2. Testăm fiecare joc, unul câte unul

Jocurile din colecția actuală:

- [ ] Tic Tac Toe
- [ ] Number Rush
- [ ] Battleship
- [ ] Connect Four
- [ ] Backgammon
- [ ] Dots & Boxes
- [ ] Ricochet
- [ ] Tilt Race
- [ ] Laser Duel

### Checklist repetat pentru fiecare joc

- [ ] Telefonul A pornește sesiunea, iar telefonul B intră.
- [ ] Verificăm ecranul de lobby și tranziția către joc.
- [ ] Verificăm că fiecare telefon afișează perspectiva și rolul corect.
- [ ] Facem cel puțin o acțiune de pe fiecare telefon.
- [ ] Verificăm că mișcările și scorul se sincronizează.
- [ ] Jucăm o partidă completă până la rezultat.
- [ ] Verificăm că ambii jucători văd același câștigător.
- [ ] Verificăm scorul sesiunii pe ambele telefoane.
- [ ] Cerem revanșă de pe telefonul A și acceptăm de pe telefonul B.
- [ ] Cerem revanșă de pe telefonul B și acceptăm de pe telefonul A.
- [ ] Refuzăm o revanșă și verificăm comportamentul ambelor telefoane.
- [ ] Schimbăm rolurile: telefonul B devine host și repetăm testul scurt.
- [ ] Dacă jocul are mod local, îl testăm pe același telefon.
- [ ] Dacă jocul are mod versus computer, jucăm o rundă completă.
- [ ] Notăm problemele de UI: spațiere, orientare, animații, text, butoane, feedback vizual și sunet.
- [ ] Notăm dacă regulile sau obiectivul nu sunt clare fără explicații.

### Clasificarea fiecărei probleme

- **P0 – Blocant:** crash, imposibilitatea conectării, pierderea achizițiilor sau joc imposibil de terminat.
- **P1 – Important:** desincronizare, rezultat diferit, ieșire greșită din sesiune, control dificil.
- **P2 – UX:** tranziții, mesaje neclare, butoane, orientare și feedback insuficient.
- **P3 – Polish:** culori, umbre, animații, sunete și mici ajustări vizuale.

Pentru fiecare problemă notăm:

- jocul;
- telefonul pe care apare;
- host sau guest;
- pașii exacți de reproducere;
- rezultatul actual;
- rezultatul dorit;
- video sau captură, dacă problema este vizuală.

Rezultat: avem inventarul complet înainte să începem modificările.

---

## 3. Reparăm comportamentul când un jucător apasă Back

Testăm separat aceste situații:

- [ ] Guest apasă Back din lobby.
- [ ] Host apasă Back din lobby.
- [ ] Guest apasă Back în timpul partidei.
- [ ] Host apasă Back în timpul partidei.
- [ ] Un jucător iese din ecranul de rezultat.
- [ ] Un jucător refuză revanșa.
- [ ] Un jucător pune aplicația în background.
- [ ] Un jucător închide forțat aplicația.
- [ ] Un telefon pierde Bluetooth temporar.

Comportamentul dorit:

- [ ] Aplicația celuilalt jucător nu se închide și nu navighează brusc înapoi.
- [ ] Jucătorul rămas vede un mesaj clar: „Opponent left the game”.
- [ ] Poate reveni controlat la lista de jocuri sau poate deschide un lobby nou.
- [ ] Scorul și starea sesiunii se închid curat.
- [ ] Evenimentul de ieșire nu este tratat ca un crash sau ca o comandă de închidere pentru ambele interfețe.
- [ ] Același comportament este folosit de toate jocurile.

Ordinea implementării:

- [ ] Reproducem problema cu loguri pe ambele telefoane.
- [ ] Identificăm dacă vine din navigare, din starea lobby-ului sau din protocolul Nearby.
- [ ] Definim un singur eveniment comun de tip „player left session”.
- [ ] Separăm ieșirea voluntară de pierderea temporară a conexiunii.
- [ ] Construim un overlay comun pentru jucătorul rămas.
- [ ] Aplicăm soluția întâi unui singur joc.
- [ ] O testăm cu rolurile inversate.
- [ ] Mutăm soluția în componentele comune.
- [ ] Retestăm toate cele nouă jocuri.

Rezultat: fiecare utilizator își controlează propriul ecran, iar ieșirea adversarului este tratată elegant.

---

## 4. Facem îmbunătățirile de gameplay și UI

- [ ] Rezolvăm întâi toate problemele P0.
- [ ] Rezolvăm apoi problemele P1.
- [ ] Grupăm problemele P2 care pot fi reparate într-o componentă comună.
- [ ] Stabilim aceleași reguli pentru butoanele Back, Exit, Rematch și Play Again.
- [ ] Uniformizăm afișarea scorului.
- [ ] Uniformizăm overlay-ul de rezultat.
- [ ] Uniformizăm mesajele de conectare, deconectare și așteptare.
- [ ] Verificăm orientarea portrait/landscape și tranzițiile dintre ele.
- [ ] Verificăm Dynamic Type și textele care pot fi tăiate.
- [ ] Verificăm contrastul, zonele de apăsare și VoiceOver pentru acțiunile importante.
- [ ] Rezolvăm problemele P3 doar după ce jocurile sunt stabile.

Regulă: reparăm mai întâi componenta comună, apoi excepțiile fiecărui joc.

---

## 5. Construim sistemul comun „How to Play”

### Alegem forma potrivită

- [ ] Pentru jocurile de tablă folosim 3–5 carduri ilustrate sau animații SwiftUI scurte.
- [ ] Pentru Ricochet, Tilt Race și Laser Duel folosim animații sau clipuri scurte care arată mișcarea dintre telefoane.
- [ ] Evităm clipurile lungi și fișierele mari care umflă aplicația.
- [ ] Tutorialele nu au nevoie de sunet; orice informație apare și ca text.

### Construim o singură componentă reutilizabilă

- [ ] Buton „?” sau „How to Play” pe ecranul fiecărui joc.
- [ ] Tutorial afișat automat la prima deschidere a jocului.
- [ ] Posibilitate de Skip.
- [ ] Posibilitate de reluare din meniul jocului.
- [ ] Indicator de progres: 1/3, 2/3, 3/3.
- [ ] Ultimul card are buton „Play”.
- [ ] Stocăm local faptul că tutorialul a fost văzut.

### Conținut minim pentru fiecare joc

- [ ] Obiectivul jocului.
- [ ] Cum controlezi jocul.
- [ ] Cum funcționează tura.
- [ ] Cum câștigi.
- [ ] Ce se întâmplă în Nearby Play, dacă este relevant.

### Ordinea producției

- [ ] Scriem storyboardul pentru toate jocurile.
- [ ] Construim componenta cu un singur joc pilot.
- [ ] Testăm tutorialul pe ambele dimensiuni de telefon.
- [ ] Adăugăm restul jocurilor.
- [ ] Verificăm că tutorialele pot fi localizate ulterior.

Rezultat: un utilizator nou înțelege fiecare joc fără să ghicească regulile.

---

## 6. Coborâm versiunea minimă de iOS

Situația actuală: proiectul are deployment target **iOS 26.4**.

Plan:

- [ ] Facem schimbarea într-un branch separat.
- [ ] Încercăm inițial deployment target iOS 17.0.
- [ ] Compilăm proiectul complet fără să modificăm logica jocurilor.
- [ ] Inventariem API-urile care cer o versiune mai nouă.
- [ ] Adăugăm alternative sau verificări de disponibilitate doar unde este necesar.
- [ ] Rulăm aplicația pe cel mai vechi simulator disponibil.
- [ ] Testăm pornirea, lista de jocuri, orientarea și toate modurile locale.
- [ ] Testăm StoreKit cu configurația locală.
- [ ] Testăm din nou Nearby Play pe cele două telefoane fizice.
- [ ] Dacă iOS 17 funcționează fără compromisuri, evaluăm dacă iOS 16 merită efortul suplimentar.
- [ ] Verificăm dimensiunea aplicației și timpul de lansare.

Important: folosim SDK-ul nou, dar reducem doar versiunea minimă acceptată.

Rezultat: NearPlay devine disponibil pentru mult mai multe dispozitive.

---

## 7. Regresie pentru plăți și acces premium

- [ ] Verificăm un joc gratuit pe instalare curată.
- [ ] Verificăm un joc premium blocat.
- [ ] Cumpărăm în Sandbox un joc individual.
- [ ] Verificăm că jocul rămâne deblocat după relansare.
- [ ] Verificăm Restore Purchases.
- [ ] Verificăm NearPlay Lifetime Pass.
- [ ] Verificăm că Lifetime Pass deblochează toate jocurile premium.
- [ ] Verificăm comportamentul fără internet după ce drepturile au fost sincronizate.
- [ ] Verificăm mesajele pentru purchase cancelled, pending și failed.
- [ ] Verificăm că prețurile sunt citite din App Store, nu scrise manual în UI.

Rezultat: modificările următoarei versiuni nu strică sistemul care funcționează deja în producție.

---

## 8. Pregătim versiunea de test înainte de ASO

- [ ] Creștem versiunea și buildul doar după ce schimbările sunt stabile.
- [ ] Facem un build Release curat.
- [ ] Îl urcăm în TestFlight.
- [ ] Instalăm buildul TestFlight pe ambele telefoane.
- [ ] Repetăm testul de conectare și câte o partidă scurtă în fiecare joc.
- [ ] Verificăm achizițiile în Sandbox/TestFlight.
- [ ] Verificăm crash-urile și hang-urile din Xcode Organizer/App Store Connect.
- [ ] Pregătim App Review Notes cu pașii pentru Nearby Play și achiziții.

Gate: nu începem reclame plătite până când buildul candidat trece această etapă.

---

## 9. Audităm și îmbunătățim pagina App Store

### Salvăm baza de comparație

- [ ] Notăm impresiile actuale.
- [ ] Notăm product page views.
- [ ] Notăm rata de conversie către download.
- [ ] Notăm downloadurile pe țări și surse.
- [ ] Notăm vânzările fiecărui In-App Purchase.
- [ ] Notăm crash rate și retention disponibile în App Store Connect.

### Verificăm metadata

- [ ] Numele aplicației.
- [ ] Subtitle.
- [ ] Promotional Text.
- [ ] Keywords fără repetiții inutile.
- [ ] Descrierea actualizată cu toate jocurile disponibile.
- [ ] What’s New pentru noua versiune.
- [ ] Categoria principală și categoria secundară.
- [ ] Age Rating.
- [ ] Support URL, Privacy Policy și Terms of Use.
- [ ] Eticheta App Privacy și dacă reflectă exact datele colectate în cod.
- [ ] Localizare English.
- [ ] Adăugarea localizării Romanian.

### Refacem prezentarea vizuală

- [ ] Prima captură explică ideea principală în mai puțin de două secunde.
- [ ] Primele trei capturi funcționează ca o poveste.
- [ ] Arătăm două telefoane și jocul care continuă între ecrane.
- [ ] Arătăm jocurile clasice.
- [ ] Arătăm modul pe același telefon și versus computer.
- [ ] Arătăm clar că nu este necesar un cont.
- [ ] Creăm un App Preview scurt, bazat pe gameplay real.
- [ ] Verificăm toate dimensiunile cerute de App Store Connect.

### După pagina principală

- [ ] Custom Product Page pentru jocurile între două telefoane.
- [ ] Custom Product Page pentru jocurile clasice.
- [ ] Custom Product Page pentru cupluri, prieteni și călătorii.
- [ ] Product Page Optimization doar după ce avem suficient trafic pentru un test relevant.

Rezultat: pagina explică produsul înainte ca utilizatorul să fie obligat să citească descrierea completă.

---

## 10. Construim materialele de marketing

Mesajul principal propus:

> **Two phones. One room. Zero internet.**

### Trei direcții de conținut

1. **Acțiune între două ecrane** – Ricochet, Laser Duel și Tilt Race.
2. **Jocuri clasice oriunde** – Backgammon, Battleship, Connect Four și celelalte jocuri de tablă.
3. **Joacă împreună fără complicații** – două telefoane, același telefon sau computer.

### Materiale necesare

- [ ] Un clip principal de 15–20 secunde.
- [ ] Trei clipuri verticale de 6–10 secunde.
- [ ] Câte un clip scurt pentru fiecare joc.
- [ ] Cinci imagini statice pentru postări.
- [ ] O imagine clară cu toate jocurile.
- [ ] Un clip care arată conectarea dintre telefoane.
- [ ] Un clip care arată cumpărarea Lifetime Pass fără să promită reduceri inexistente.
- [ ] Link App Store pregătit pentru distribuire.
- [ ] O pagină web simplă cu clipul principal, jocurile și butonul Download on the App Store.

### Canale organice

- [ ] TikTok.
- [ ] Instagram Reels.
- [ ] YouTube Shorts.
- [ ] Reddit, în comunități relevante, cu o postare autentică despre procesul de dezvoltare.
- [ ] Grupuri și comunități pentru jocuri de cuplu, călătorii și local multiplayer.
- [ ] Micro-creatori care pot filma două telefoane în aceeași cameră.

### Reclame plătite

- [ ] Nu pornim reclamele înainte ca pagina App Store să fie optimizată.
- [ ] Începem cu un buget mic și o singură ipoteză per campanie.
- [ ] Testăm Apple Ads pe cuvinte cu intenție clară.
- [ ] Testăm un singur clip pe Meta/TikTok înainte să producem multe variante.
- [ ] Folosim linkuri sau Custom Product Pages diferite pentru fiecare campanie.
- [ ] Măsurăm costul per download și venitul pe download.
- [ ] Oprim rapid campaniile care nu se apropie de profitabilitate.
- [ ] Nu mărim bugetul până când venitul estimat per utilizator justifică prețul instalării.

Rezultat: aflăm cu bani puțini ce mesaj și ce public funcționează.

---

## 11. Funcții de creștere pentru o versiune viitoare

Acestea nu blochează stabilizarea, dar pot ajuta promovarea:

- [ ] „Invite Friend” în lobby.
- [ ] Share Sheet cu linkul App Store.
- [ ] QR code pentru instalarea NearPlay pe al doilea telefon.
- [ ] Card de rezultat care poate fi distribuit.
- [ ] Solicitare de rating după câteva partide finalizate cu succes, nu la prima deschidere.
- [ ] Formular simplu de feedback în Settings.
- [ ] Contor local pentru jocurile preferate și tutorialele vizualizate.
- [ ] Evaluarea unei soluții de analytics care respectă confidențialitatea, doar dacă avem nevoie de date din interiorul funnelului.

---

## 12. Ordinea concretă pentru prima zi

Mâine nu încercăm să rezolvăm tot planul. Facem doar:

- [ ] Pasul 0: salvăm baza stabilă.
- [ ] Pasul 1: verificăm conexiunea generală.
- [ ] Alegem primul joc.
- [ ] Îl testăm complet folosind checklistul.
- [ ] Reproducem problema de Back din minimum două situații.
- [ ] Notăm exact ce se întâmplă pe fiecare telefon.
- [ ] Decidem prima corecție numai după ce avem reproducerea clară.

La finalul primei zile trebuie să avem dovezi și priorități clare, nu multe modificări începute simultan.

---

## Definiția finală de „gata pentru promovare”

- [ ] Toate jocurile pot fi terminate pe ambele telefoane.
- [ ] Scorurile și rezultatele sunt sincronizate.
- [ ] Ieșirea unui jucător nu închide interfața celuilalt.
- [ ] Fiecare joc are un tutorial ușor de găsit.
- [ ] Aplicația rulează pe versiunea minimă de iOS aleasă.
- [ ] Achizițiile și Restore Purchases funcționează.
- [ ] Buildul TestFlight trece regresia pe ambele telefoane.
- [ ] Pagina App Store prezintă jocurile actuale.
- [ ] Avem cel puțin un clip principal și trei clipuri scurte.
- [ ] Putem măsura separat rezultatele fiecărui canal de marketing.

