"""Empacota somente fontes publicas versionadas, sem materiais privados."""
import hashlib,subprocess,zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
files=subprocess.check_output(['git','ls-files','-z'],cwd=root).decode().split('\0')
allowed={'README.md','AUTORES.md','docker-compose.yml','diagramabancodedadosii.drawio','diagramabancodedadosii.drawio.pdf','.gitignore'}
selected=[n for n in files if n in allowed or n.startswith(('sql/','scripts/','docs/','evidencias/'))]
private={'agent.md','agents.md','spec.md','prompt-marco-2.md','prompt.md','0.1 projeto_academico_bd2_2026-2.pdf'}
assert not any(Path(n).name.lower() in private for n in selected)
folder=root/'entrega';folder.mkdir(exist_ok=True);dest=folder/'Projeto_BD2_Marco2.zip'
with zipfile.ZipFile(dest,'w',zipfile.ZIP_DEFLATED) as archive:
 for name in selected:archive.write(root/name,name)
digest=hashlib.sha256(dest.read_bytes()).hexdigest();(folder/'SHA256.txt').write_text(digest+'  '+dest.name+'\n');print(dest);print(digest)
