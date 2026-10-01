# TODO

Przenoszenie plików na tym samym dysku działa (Finder wykonuje `FPMoveOperation`).
Otwarte sprawy z audytu z 2026-10-01:

- [ ] Tryb "move": gdy cel wybierze kopiowanie (inny dysk, Mail, przeglądarka, ⌥),
      plik jest kopiowany, a i tak znika z półki (`ShelfDragOperationPolicy.shouldRemoveFromShelf`).
- [ ] Mieszane zaznaczenie (move + copy) wymusza kopiowanie całego przeciągnięcia,
      a pliki w trybie move i tak znikają z półki.
- [ ] Preferencja "Copy on drag" działa tylko wewnątrz aplikacji, czyli praktycznie nigdy.
- [ ] Nieaktualne zakładki (stale bookmarks) nigdy nie są odświeżane.
