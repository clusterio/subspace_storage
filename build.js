"use strict";
const events = require("events");
const fs = require("fs-extra");
const JSZip = require("jszip");
const klaw = require("klaw");
const path = require("path");
const yargs = require("yargs");


async function main() {
	const args = yargs
		.scriptName("build")
		.options({
			'clean': { describe: "Remove previous builds", type: 'boolean', default: false },
			'build': { describe: "Build mod", type: 'boolean', default: true },
			'pack': { describe: "Pack into zip file", type: 'boolean', default: true },
			'source-dir': { describe: "Path to mod source directory", nargs: 1, type: 'string', default: "src" },
			'output-dir': { describe: "Path to output built mod", nargs: 1, type: 'string', default: "dist" },
		})
		.argv
	;

	let info = JSON.parse(await fs.readFile(path.join(args.sourceDir, "info.json")));

	if (args.clean) {
		let splitter = /^(.*)_(\d+\.\d+\.\d+)(\.zip)?$/
		for (let entry of await fs.readdir(args.outputDir)) {
			let match = splitter.exec(entry);
			if (match) {
				let [, name, version] = match;
				if (name === info.name) {
					let modPath = path.join(args.outputDir, entry);
					console.log(`Removing ${modPath}`);
					await fs.remove(modPath);
				}
			}
		}
	}

	if (args.build) {
		await fs.ensureDir(args.outputDir);
		let modName = `${info.name}_${info.version}`;

		if (args.pack) {
			let zip = new JSZip();
			let walker = klaw(args.sourceDir)
				.on('data', item => {
					if (item.stats.isFile()) {
						let zipPath = path.join(modName, path.relative(args.sourceDir, item.path));
						zip.file(zipPath, fs.createReadStream(item.path));
					}
				});
			await events.once(walker, 'end');

			let modPath = path.join(args.outputDir, `${modName}.zip`);
			console.log(`Writing ${modPath}`);
			let writeStream = zip.generateNodeStream().pipe(fs.createWriteStream(modPath));
			await events.once(writeStream, 'finish');

		} else {
			let modDir = path.join(args.outputDir, modName);
			if (await fs.exists(modDir)) {
				console.log(`Removing existing build ${modDir}`);
				await fs.remove(modDir);
			}
			console.log(`Building ${modDir}`);
			await fs.copy(args.sourceDir, modDir);
		}
	}
}

if (module === require.main) {
	main().catch(err => { console.log(err) });
}
