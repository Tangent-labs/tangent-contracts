import {exec} from "child_process";
import * as fs from "fs";
import * as path from "path";

// Définition des répertoires
const SRC_DIR = "src/tgUSD";
const FLATTENED_DIR = "flattened";

// Fonction pour exécuter une commande shell
const runCommand = (cmd: string): Promise<string> => {
    return new Promise((resolve, reject) => {
        exec(cmd, (error, stdout, stderr) => {
            if (error) {
                console.error(`❌ Erreur: ${stderr}`);
                reject(error);
            } else {
                resolve(stdout);
            }
        });
    });
}; // Fonction pour récupérer tous les fichiers Solidity (récursivement)
const getSolidityFiles = (dir: string): string[] => {
    let solFiles: string[] = [];
    const entries = fs.readdirSync(dir, {withFileTypes: true});

    for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            // Si c'est un dossier, on recherche récursivement les fichiers Solidity
            solFiles = solFiles.concat(getSolidityFiles(fullPath));
        } else if (entry.isFile() && entry.name.endsWith(".sol")) {
            // Ajouter le fichier Solidity à la liste
            solFiles.push(fullPath);
        }
    }
    return solFiles;
};

// Fonction principale pour aplatir tous les fichiers Solidity
const flattenAll = async () => {
    try {
        // Créer le dossier de sortie s'il n'existe pas
        if (!fs.existsSync(FLATTENED_DIR)) {
            fs.mkdirSync(FLATTENED_DIR, {recursive: true});
        }

        // Récupérer tous les fichiers Solidity récursivement
        const files = getSolidityFiles(SRC_DIR);

        if (files.length === 0) {
            console.log("⚠️ Aucun fichier Solidity trouvé !");
            return;
        }

        // Boucle pour aplatir chaque fichier Solidity
        for (const file of files) {
            // Extraire seulement le nom du fichier sans son chemin complet
            const fileName = path.basename(file, ".sol");
            const outputFile = path.join(FLATTENED_DIR, `${fileName}_flat.sol`);

            console.log(`🔄 Aplatissement de ${fileName}...`);

            // Utilisation de la redirection via un fichier pour éviter l'erreur de redirection
            await runCommand(`forge flatten ${file} > ${outputFile}`);
            console.log(`✅ Fichier aplati: ${outputFile}`);
        }

        console.log("🎉 Tous les fichiers Solidity ont été aplatis avec succès !");
    } catch (error) {
        console.error("❌ Une erreur s'est produite:", error);
    }
};

// Exécuter le script
flattenAll();
