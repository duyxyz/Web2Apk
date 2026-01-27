const fs = require('fs');
const path = require('path');

function copyAssets() {
    const input = path.join('assets', 'icon-192 (2).png');
    const assetsDir = 'assets';
    const filesToReplace = ['icon.png', 'adaptive-icon.png', 'favicon.png', 'splash-icon.png', 'icon-192.png'];

    console.log(`Copying original PNG ${input} to all asset locations...`);

    try {
        if (!fs.existsSync(input)) {
            console.error(`Error: Source file not found at ${input}`);
            process.exit(1);
        }

        const buffer = fs.readFileSync(input);

        for (const file of filesToReplace) {
            const outputPath = path.join(assetsDir, file);
            fs.writeFileSync(outputPath, buffer);
            console.log(`Updated: ${outputPath}`);
        }

        console.log('Update complete!');
    } catch (err) {
        console.error('Error during copying:', err);
        process.exit(1);
    }
}

copyAssets();
