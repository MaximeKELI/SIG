class GalleryPhoto {
  final String asset;
  final String caption;
  final String event;

  const GalleryPhoto({
    required this.asset,
    required this.caption,
    required this.event,
  });
}

class GalleryCatalog {
  static const _base = 'assets/images/gallery';

  static const graine = <GalleryPhoto>[
    GalleryPhoto(
      asset: '$_base/01-graine-espoir-formation-agro.jpg',
      caption: 'Formation agro',
      event: 'graine',
    ),
    GalleryPhoto(
      asset: '$_base/02-graine-espoir-formation-agro.jpg',
      caption: 'Sur le terrain',
      event: 'graine',
    ),
    GalleryPhoto(
      asset: '$_base/03-graine-espoir-planche-carotte.jpg',
      caption: 'Planche carotte',
      event: 'graine',
    ),
    GalleryPhoto(
      asset: '$_base/04-graine-espoir-planche-carotte.jpg',
      caption: 'Planche carotte',
      event: 'graine',
    ),
    GalleryPhoto(
      asset: '$_base/05-graine-espoir-pepiniere-betterave.jpg',
      caption: 'Pépinière betterave',
      event: 'graine',
    ),
    GalleryPhoto(
      asset: '$_base/06-graine-espoir-pepiniere-betterave.jpg',
      caption: 'Pépinière',
      event: 'graine',
    ),
    GalleryPhoto(
      asset: '$_base/07-graine-espoir-neem.jpg',
      caption: 'Neem',
      event: 'graine',
    ),
    GalleryPhoto(
      asset: '$_base/08-graine-espoir-neem.jpg',
      caption: 'Neem',
      event: 'graine',
    ),
  ];

  /// Sélection hero Accueil (carrousel).
  static const hero = <GalleryPhoto>[
    GalleryPhoto(
      asset: '$_base/01-graine-espoir-formation-agro.jpg',
      caption: 'Formation agro',
      event: 'hero',
    ),
    GalleryPhoto(
      asset: '$_base/11-soiree-cinema-projection.jpg',
      caption: 'Projection cinéma',
      event: 'hero',
    ),
    GalleryPhoto(
      asset: '$_base/03-graine-espoir-planche-carotte.jpg',
      caption: 'Planche carotte',
      event: 'hero',
    ),
    GalleryPhoto(
      asset: '$_base/14-soiree-cinema-table-ronde.jpg',
      caption: 'Table ronde',
      event: 'hero',
    ),
    GalleryPhoto(
      asset: '$_base/05-graine-espoir-pepiniere-betterave.jpg',
      caption: 'Pépinière',
      event: 'hero',
    ),
    GalleryPhoto(
      asset: '$_base/15-soiree-cinema-networking.jpg',
      caption: 'Networking',
      event: 'hero',
    ),
    GalleryPhoto(
      asset: '$_base/02-graine-espoir-formation-agro.jpg',
      caption: 'Sur le terrain',
      event: 'hero',
    ),
    GalleryPhoto(
      asset: '$_base/09-soiree-cinema-ouverture.jpg',
      caption: 'Ouverture',
      event: 'hero',
    ),
  ];

  static const cinema = <GalleryPhoto>[
    GalleryPhoto(
      asset: '$_base/09-soiree-cinema-ouverture.jpg',
      caption: 'Ouverture',
      event: 'cinema',
    ),
    GalleryPhoto(
      asset: '$_base/10-soiree-cinema-ouverture.jpg',
      caption: 'Ouverture',
      event: 'cinema',
    ),
    GalleryPhoto(
      asset: '$_base/11-soiree-cinema-projection.jpg',
      caption: 'Projection',
      event: 'cinema',
    ),
    GalleryPhoto(
      asset: '$_base/12-soiree-cinema-projection.jpg',
      caption: 'Projection',
      event: 'cinema',
    ),
    GalleryPhoto(
      asset: '$_base/13-soiree-cinema-table-ronde.jpg',
      caption: 'Table ronde',
      event: 'cinema',
    ),
    GalleryPhoto(
      asset: '$_base/14-soiree-cinema-table-ronde.jpg',
      caption: 'Table ronde',
      event: 'cinema',
    ),
    GalleryPhoto(
      asset: '$_base/15-soiree-cinema-networking.jpg',
      caption: 'Networking',
      event: 'cinema',
    ),
    GalleryPhoto(
      asset: '$_base/16-soiree-cinema-networking.jpg',
      caption: 'Collation',
      event: 'cinema',
    ),
  ];
}
