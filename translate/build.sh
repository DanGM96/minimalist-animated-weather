#!/bin/sh
# Version: 9 (Le retour du préfixe obligatoire de KDE)

DIR=`cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd`

# On extrait l'ID proprement depuis metadata.json
plasmoidName=$(grep '"Id"' "$DIR/../metadata.json" | cut -d'"' -f4)

if [ -z "$plasmoidName" ]; then
    echo "[build] Erreur: Impossible de lire l'ID dans metadata.json."
    exit 1
fi

# LE VOICI : KDE exige que le fichier .mo commence par "plasma_applet_"
projectName="plasma_applet_${plasmoidName}"

if [ -z "$(which msgfmt)" ]; then
    echo "[build] Erreur: msgfmt introuvable."
    exit 1
fi

echo "[build] Nettoyage des anciens fichiers de traduction..."
rm -rf "$DIR/../contents/locale"/*/LC_MESSAGES/*.mo

echo "[build] Compilation pour le domaine : $projectName"
catalogs=`find . -name '*.po' | sort`

for cat in $catalogs; do
    catLocale=`basename ${cat%.*}`
    installPath="$DIR/../contents/locale/${catLocale}/LC_MESSAGES/${projectName}.mo"

    mkdir -p "$(dirname "$installPath")"
    msgfmt -o "${installPath}" "$cat"
    echo " -> Généré : $installPath"
done

echo "[build] Compilation terminée avec succès."
