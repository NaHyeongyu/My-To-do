import shutil
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "1_Routine_Control_Tower_Planning.docx"
OUT = ROOT / "output" / "doc" / "1_Routine_Control_Tower_Planning_v1.1.docx"

W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
XML = "http://www.w3.org/XML/1998/namespace"

ET.register_namespace("w", W)
ET.register_namespace("r", R)


def qn(name: str) -> str:
    prefix, local = name.split(":")
    if prefix == "w":
        return f"{{{W}}}{local}"
    if prefix == "r":
        return f"{{{R}}}{local}"
    raise ValueError(name)


def text_from(el: ET.Element) -> str:
    parts = []
    for node in el.iter():
        if node.tag == qn("w:t"):
            parts.append(node.text or "")
        elif node.tag == qn("w:tab"):
            parts.append("\t")
        elif node.tag == qn("w:br"):
            parts.append("\n")
    return "".join(parts).strip()


def clear_and_set_text(el: ET.Element, text: str) -> None:
    texts = list(el.iter(qn("w:t")))
    if not texts:
        return
    texts[0].text = text
    texts[0].set(f"{{{XML}}}space", "preserve")
    for t in texts[1:]:
        t.text = ""


def paragraph(text: str, style: str | None = None) -> ET.Element:
    p = ET.Element(qn("w:p"))
    if style:
        ppr = ET.SubElement(p, qn("w:pPr"))
        pstyle = ET.SubElement(ppr, qn("w:pStyle"))
        pstyle.set(qn("w:val"), style)
    r = ET.SubElement(p, qn("w:r"))
    lines = text.split("\n")
    for i, line in enumerate(lines):
        if i:
            ET.SubElement(r, qn("w:br"))
        t = ET.SubElement(r, qn("w:t"))
        t.set(f"{{{XML}}}space", "preserve")
        t.text = line
    return p


def table(rows: list[list[str]], style: str = "TableGrid") -> ET.Element:
    tbl = ET.Element(qn("w:tbl"))
    tbl_pr = ET.SubElement(tbl, qn("w:tblPr"))
    tbl_style = ET.SubElement(tbl_pr, qn("w:tblStyle"))
    tbl_style.set(qn("w:val"), style)
    tbl_w = ET.SubElement(tbl_pr, qn("w:tblW"))
    tbl_w.set(qn("w:w"), "0")
    tbl_w.set(qn("w:type"), "auto")
    borders = ET.SubElement(tbl_pr, qn("w:tblBorders"))
    for border_name in ["top", "left", "bottom", "right", "insideH", "insideV"]:
        border = ET.SubElement(borders, qn(f"w:{border_name}"))
        border.set(qn("w:val"), "single")
        border.set(qn("w:sz"), "4")
        border.set(qn("w:space"), "0")
        border.set(qn("w:color"), "D9D9D9")

    grid = ET.SubElement(tbl, qn("w:tblGrid"))
    col_count = max(len(row) for row in rows)
    for _ in range(col_count):
        col = ET.SubElement(grid, qn("w:gridCol"))
        col.set(qn("w:w"), str(max(1600, 9000 // max(1, col_count))))

    for row in rows:
        tr = ET.SubElement(tbl, qn("w:tr"))
        for cell_text in row:
            tc = ET.SubElement(tr, qn("w:tc"))
            tc_pr = ET.SubElement(tc, qn("w:tcPr"))
            tc_w = ET.SubElement(tc_pr, qn("w:tcW"))
            tc_w.set(qn("w:w"), str(max(1600, 9000 // max(1, col_count))))
            tc_w.set(qn("w:type"), "dxa")
            tc.append(paragraph(cell_text))
    return tbl


def find_child_index(body: ET.Element, exact_text: str) -> int:
    for index, child in enumerate(list(body)):
        if text_from(child) == exact_text:
            return index
    raise ValueError(f"Could not find block: {exact_text}")


def find_child_index_containing(body: ET.Element, needle: str) -> int:
    for index, child in enumerate(list(body)):
        if needle in text_from(child):
            return index
    raise ValueError(f"Could not find block containing: {needle}")


def insert_after(body: ET.Element, exact_text: str, new_blocks: list[ET.Element]) -> None:
    index = find_child_index(body, exact_text)
    for offset, block in enumerate(new_blocks, start=1):
        body.insert(index + offset, block)


def insert_after_containing(body: ET.Element, needle: str, new_blocks: list[ET.Element]) -> None:
    index = find_child_index_containing(body, needle)
    for offset, block in enumerate(new_blocks, start=1):
        body.insert(index + offset, block)


def replace_exact_text(root: ET.Element, old: str, new: str) -> int:
    count = 0
    for el in root.iter():
        if text_from(el) == old:
            clear_and_set_text(el, new)
            count += 1
    return count


def replace_cell_containing(root: ET.Element, needle: str, new: str) -> int:
    count = 0
    for cell in root.iter(qn("w:tc")):
        if needle in text_from(cell):
            clear_and_set_text(cell, new)
            count += 1
    return count


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(SRC, OUT)

    with zipfile.ZipFile(OUT, "r") as zin:
        files = {name: zin.read(name) for name in zin.namelist()}

    root = ET.fromstring(files["word/document.xml"])
    body = root.find(qn("w:body"))
    if body is None:
        raise RuntimeError("word/document.xml has no body")

    replacements = {
        "서버 없는 개인 루틴 관제 To-do 앱 기획서":
            "서버 없는 개인 시간 관제 루틴 앱 기획서",
        "5단계 기획: 데이터 기록 → 하루 리뷰 → 통계 → 로컬 알림 → 위젯":
            "제품 방향: 반복 루틴으로 입력 마찰을 줄이고, 시간 투자 데이터를 관제한다",
        "Version 1.0 · 2026-06-17 · iOS / SwiftUI / Local-first":
            "Version 1.1 · 2026-06-18 · iOS / SwiftUI / Local-first",
        "실패를 지우지 않고, 실패를 분석한다.":
            "기억이 아니라 기록으로 내 시간을 관제한다.",
        "내 하루를 기록하고, 실패 이유까지 분석하는 개인 운영 시스템":
            "반복 루틴을 따라가며 시간 투자와 실패 원인을 최소 입력으로 기록하는 개인 운영 시스템",
        "서버 없는 iOS 전용 개인 루틴 관제 앱":
            "서버 없는 iOS 전용 개인 시간/루틴 관제 앱",
        "이 앱은 일반적인 To-do 앱처럼 단순히 할 일을 만들고 체크하는 것을 목표로 하지 않는다. 핵심은 사용자가 매일 실행한 루틴의 결과를 남기고, 실패했을 때 그 원인을 함께 기록해서 장기적인 실행 패턴을 파악하는 것이다.":
            "이 앱은 일반적인 To-do 앱처럼 단순히 할 일을 만들고 체크하는 것을 목표로 하지 않는다. 핵심은 사용자가 자신의 인생을 돌아볼 때 기억이 아니라 객관적인 시간 투자 데이터를 기준으로 판단할 수 있게 만드는 것이다.",
        "따라서 제품 카테고리를 단순히 To-do로 잡기보다는 ‘개인 루틴 관제 앱’, ‘실행 데이터 기록 앱’, ‘시간 투자 포트폴리오 앱’에 가깝게 정의하는 것이 좋다.":
            "사람들이 기록하지 않는 이유는 의지가 부족해서가 아니라 입력이 귀찮기 때문이다. 매일 새 플랜을 세우고, 수행 여부와 시간을 다시 입력하는 과정 자체가 병목이다. 따라서 제품 카테고리는 ‘개인 루틴 관제 앱’, ‘입력 마찰을 줄인 실행 데이터 기록 앱’, ‘시간 투자 포트폴리오 앱’에 가깝게 정의한다.",
        "사용자가 하루의 루틴을 빠르게 확인하고, 실행 결과를 기록하고, 시간이 쌓였을 때 자기 생활의 패턴을 이해할 수 있게 만드는 것이 목표다.":
            "사용자가 매일 새 계획을 세우지 않아도 반복 루틴을 따라가며 실행 데이터를 남기고, 시간이 쌓였을 때 자기 생활의 패턴과 시간 투자 구조를 이해할 수 있게 만드는 것이 목표다.",
        "사용자가 앱을 설치한 뒤 루틴을 만들고, 오늘의 실행 결과를 성공/실패/스킵으로 기록할 수 있게 한다. 1단계의 성공 여부는 ‘기록이 빠르고 부담 없는가’로 판단한다.":
            "사용자가 앱을 설치한 뒤 반복 루틴을 만들고, 오늘의 실행 결과를 성공/실패/스킵으로 기록할 수 있게 한다. 1단계의 성공 여부는 ‘매일 새 계획을 세우지 않아도 되는가’, ‘기록이 빠르고 부담 없는가’로 판단한다.",
        "일주일 동안 어디에 시간을 썼는지 볼 수 있다.":
            "주/월/년 단위로 어디에 시간을 썼는지 볼 수 있다.",
        "어떤 이유로 실패했는지 볼 수 있다.":
            "어떤 이유로 병목이 생겼는지 볼 수 있다.",
        "실제 투자 시간 기록":
            "실제 투자 시간 빠른 기록",
        "차분하고 분석적이어야 한다.":
            "차분하고 분석적이어야 한다.",
    }
    for old, new in replacements.items():
        replace_exact_text(root, old, new)

    insert_after_containing(
        body,
        "핵심 루프",
        [
            paragraph("1.1 방향 재정의", "Heading2"),
            paragraph(
                "문제의 출발점은 사람들이 자신의 시간을 객관적으로 보지 못한다는 데 있다. 대부분은 ‘이번 달에 공부를 꽤 했다’, ‘운동을 별로 못 했다’처럼 기억으로 회고한다. 하지만 기억은 과장되거나 지워지기 쉽고, 실제로 어디에 몇 시간을 투자했는지 알려주지 않는다."
            ),
            paragraph(
                "기록이 부족한 이유는 의지 부족이 아니라 입력 마찰이다. 매일 플랜을 새로 세우고, 실행 결과와 실제 시간을 다시 입력하는 과정은 귀찮다. 이 앱은 이 병목을 반복 루틴, 로컬 알림, 위젯, 빠른 체크인으로 줄여야 한다."
            ),
            paragraph(
                "제품의 핵심 방향은 ‘최소 입력으로 최대 관제력’을 제공하는 것이다. UI/UX는 사용자가 생각 없이 기록할 수 있을 만큼 간단해야 하고, 쌓인 데이터는 사용자가 자기 시간을 통제한다고 느낄 만큼 선명해야 한다."
            ),
            table(
                [
                    ["핵심 전제", "내용"],
                    ["객관 데이터 부족", "사람은 자신의 시간 투자를 기억으로 회고하지만, 기억은 부정확하다."],
                    ["기록 회피의 원인", "기록을 안 하는 이유는 대부분 귀찮음과 반복 입력 부담이다."],
                    ["제품 해결 방식", "반복 루틴을 미리 설정하고 알림, 위젯, 빠른 액션으로 흐름을 따라가게 한다."],
                    ["UX 원칙", "입력은 최소화하고, 시간 관제와 회고 능력은 극대화한다."],
                ]
            ),
        ],
    )

    insert_after(
        body,
        "반복 실패 루틴과 실패 사유를 찾아 루틴을 조정한다.",
        [
            paragraph("매일 새 플랜을 세우지 않아도 반복 루틴이 오늘 계획으로 자동 전개된다.", "ListBullet"),
            paragraph("알림, 위젯, 빠른 액션으로 기록 입력을 최소화한다.", "ListBullet"),
            paragraph("간단한 조작으로 계획 시간, 실제 시간, 실패 사유를 관제할 수 있게 한다.", "ListBullet"),
        ],
    )

    insert_after_containing(
        body,
        "실행량 불명확",
        [
            paragraph("3.3 핵심 병목과 해결해야 하는 문제", "Heading2"),
            paragraph(
                "이 제품의 핵심 병목은 ‘기록해야 통계가 생기지만, 기록 자체가 귀찮다’는 점이다. 따라서 기능을 많이 넣는 것보다, 사용자가 자연스럽게 기록하게 만드는 접점 설계가 중요하다."
            ),
            table(
                [
                    ["병목", "사용자 문제", "해결 방향"],
                    ["매일 계획 피로", "매일 새로 플랜을 세우는 순간 사용이 끊긴다.", "반복 루틴 템플릿을 오늘 계획으로 자동 전개한다."],
                    ["기록 입력 귀찮음", "수행 후 앱을 열고 상세 입력하는 과정이 부담스럽다.", "알림, 위젯, Today 빠른 액션으로 성공/실패/스킵을 즉시 기록한다."],
                    ["실제 시간 정확도", "정확히 몇 분 했는지 입력하기 귀찮다.", "기본값은 계획 시간으로 두고, 5/15/30/60분 빠른 수정 칩을 제공한다."],
                    ["실패 사유 입력", "텍스트 입력은 번거로워서 실패 원인이 남지 않는다.", "기본 실패 사유 버튼, 최근 사유, 기타 선택만 제공한다."],
                    ["알림 피로", "알림이 많으면 꺼버린다.", "루틴별 알림, 조용한 시간, 하루 리뷰 알림을 분리해 통제하게 한다."],
                    ["관제 화면 복잡도", "통계가 복잡하면 다시 보지 않는다.", "Today는 핵심 상태만, Analytics는 주/월/년 상세 관제로 단계화한다."],
                    ["데이터 신뢰도", "미기록을 무조건 실패로 처리하면 데이터가 왜곡된다.", "미기록, 실패, 스킵을 분리하고 데이터 공백을 명확히 표시한다."],
                ]
            ),
        ],
    )

    insert_after(
        body,
        "문장은 짧고 명확하게 쓴다.",
        [
            paragraph("입력은 한 화면, 한 탭, 짧은 선택지 중심으로 설계한다.", "ListBullet"),
            paragraph("관제 화면은 복잡한 설명보다 상태, 시간, 위험 신호를 먼저 보여준다.", "ListBullet"),
            paragraph("사용자가 통제력을 느끼게 하되, 기록 부담을 늘리지 않는다.", "ListBullet"),
        ],
    )

    replace_cell_containing(
        root,
        "1은 내 하루를 관제하는 개인 루틴 앱입니다",
        "한국어1은 내 시간을 관제하는 개인 루틴 앱입니다.반복 루틴을 설정하고, 알림과 위젯을 따라가며 최소 입력으로 실행 데이터를 남겨보세요.시간이 쌓이면 1은 당신이 어디에 시간을 투자했는지, 어떤 병목에서 자주 무너지는지 보여줍니다.로그인 없이. 서버 없이. 내 iPhone 안에서만.영어1 is a private control tower for your time.Set recurring routines, follow lightweight reminders, and capture execution data with minimal input.Over time, 1 shows where your hours went and where your routines break down.No account. No server. Just your routine data, privately on your iPhone.",
    )
    replace_cell_containing(
        root,
        "사용자는 서버나 계정 없이 iPhone에서 루틴을 만들 수 있다",
        "사용자는 서버나 계정 없이 iPhone에서 반복 루틴을 만들 수 있다.매일 성공 / 실패 / 스킵을 최소 입력으로 기록할 수 있다.실패한 이유를 남길 수 있다.하루 끝에 리뷰를 작성할 수 있다.주/월/년 단위로 어디에 시간을 썼는지 볼 수 있다.어떤 이유로 병목이 생겼는지 볼 수 있다.루틴 알림을 받을 수 있다.홈 화면 위젯에서 오늘 상태를 확인할 수 있다.",
    )

    files["word/document.xml"] = ET.tostring(root, encoding="utf-8", xml_declaration=True)

    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as zout:
        for name, data in files.items():
            zout.writestr(name, data)

    print(OUT)


if __name__ == "__main__":
    main()
