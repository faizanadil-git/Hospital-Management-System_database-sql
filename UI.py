###############################################################################
#  HOSPITAL / PHARMACY MANAGEMENT – PyQt5 + SQL-Server
###############################################################################
from PyQt5.QtWidgets import QTabWidget
import sys, hashlib
from datetime import datetime
from decimal import Decimal

import pyodbc
from PyQt5.QtCore    import Qt
from PyQt5.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QHBoxLayout, QLabel, QLineEdit,
    QPushButton, QMessageBox, QTableWidget, QTableWidgetItem, QHeaderView,
    QGroupBox, QGridLayout, QComboBox, QStackedWidget, QSpinBox
)

# ─────────────────────────────────────────────────────────────────────────────
#  DB CONNECTION  (edit if your instance differs)
# ─────────────────────────────────────────────────────────────────────────────
CONNECT_STRING = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=DESKTOP-PKT7RAS\\SQLEXPRESS;"
    "DATABASE=PharmacyManagementSystem2;"
    "Trusted_Connection=yes;"
)

# ─────────────────────────────────────────────────────────────────────────────
#  SMALL UI HELPERS
# ─────────────────────────────────────────────────────────────────────────────
def banner(text):
    w = QLabel(text)
    w.setAlignment(Qt.AlignCenter)
    w.setStyleSheet("font-size:24px;font-weight:bold;color:#0078d4;")
    return w

def modern_button(text, kind="primary"):
    c = {
        "primary":   ("#0078d4","#005a9e"),
        "success":   ("#107c10","#0c5e0c"),
        "danger":    ("#d13438","#a12226"),
        "secondary":("#f3f2f1","#e1dfdd")
    }[kind]
    b = QPushButton(text)
    b.setMinimumHeight(32)
    b.setStyleSheet(f"""
        QPushButton{{background:{c[0]};color:white;font-weight:bold;
                     border-radius:5px;padding:6px 14px}}
        QPushButton:hover{{background:{c[1]}}}
    """)
    return b

def nice_line(ph=""):
    e = QLineEdit()
    e.setPlaceholderText(ph)
    e.setMinimumHeight(28)
    return e

def spin(minv, maxv):
    s = QSpinBox()
    s.setRange(minv, maxv)
    s.setMinimumHeight(28)
    return s

# ─────────────────────────────────────────────────────────────────────────────
#  DATABASE ADAPTER  (all SQL in one place)
# ─────────────────────────────────────────────────────────────────────────────
class DB:
    def __init__(self):
        self.cn  = pyodbc.connect(CONNECT_STRING, autocommit=True)
        self.cur = self.cn.cursor()

    # auth
    def login(self, u, p):
        h = hashlib.sha256(p.encode()).digest()
        self.cur.execute(
            "SELECT r.RoleName,u.FullName "
            "FROM [User] u JOIN Role r ON r.RoleID=u.RoleID "
            "WHERE u.Username=? AND u.PasswordHash=? AND u.IsActive=1",
            u, pyodbc.Binary(h)
        )
        r = self.cur.fetchone()
        return (r.RoleName, r.FullName) if r else (None, None)

    # patients
    def new_pid(self):
        self.cur.execute("EXEC SP_GenerateNextPatientID")
        return self.cur.fetchone()[0]

    def add_pat(self, p):
        self.cur.execute(
            "INSERT INTO Patient(Patient_ID,First_Name,Last_Name,Date_of_Birth,Gender,Email,Created_Date,Is_Active) "
            "VALUES(?,?,?,?,?, ?,SYSDATETIME(),1)",
            p['id'], p['first'], p['last'], p['dob'], p['gender'], p['email']
        )

    def upd_pat(self, p):
        self.cur.execute(
            "UPDATE Patient SET First_Name=?,Last_Name=?,Date_of_Birth=?,Gender=?,Email=?,Modified_Date=SYSDATETIME() "
            "WHERE Patient_ID=? AND Is_Active=1",
            p['first'], p['last'], p['dob'], p['gender'], p['email'], p['id']
        )
        return self.cur.rowcount

    def get_pat(self, pid):
        self.cur.execute(
            "SELECT Patient_ID,First_Name,Last_Name,"
            "CONVERT(varchar(10),Date_of_Birth,23) AS DOB,Gender,Email "
            "FROM Patient WHERE Patient_ID=? AND Is_Active=1",
            pid
        )
        return self.cur.fetchone()

    # doctors
    def specs(self):
        self.cur.execute("SELECT DISTINCT Specialization FROM Doctor WHERE Is_Active=1")
        return [r[0] for r in self.cur.fetchall()]

    def docs_by_spec(self, sp):
        self.cur.execute(
            "SELECT Doctor_ID,Full_Name,Room_No FROM Doctor "
            "WHERE Is_Active=1 AND Specialization=? ORDER BY Full_Name",
            sp
        )
        return self.cur.fetchall()

    # meds / prescriptions
    def med_search(self, txt):
        like = f"%{txt}%"
        self.cur.execute("""
            SELECT m.Generic_Name,m.Brand_Name,m.Medication_ID,
                   ISNULL(i.Quantity,0) AS Stock
            FROM Medication m
            LEFT JOIN Medication_Inventory i ON i.Medication_ID=m.Medication_ID
            WHERE m.Is_Active=1 AND (m.Generic_Name LIKE ? OR m.Brand_Name LIKE ?)
            ORDER BY m.Generic_Name,m.Brand_Name
        """, like, like)
        return self.cur.fetchall()

    def new_rxid(self):
        self.cur.execute("EXEC SP_GenerateNextPrescriptionID")
        return self.cur.fetchone()[0]

    def add_rx(self, r):
        self.cur.execute("""
            INSERT INTO Prescription
            (Prescription_ID,Patient_ID,Medication_ID,Prescription_Date,
             Dosage,Quantity,Days_Supply,Refills_Authorized,Refills_Remaining,
             Instructions,Status,Created_Date)
            VALUES(?,?,?,?,?,?,?,?,?,'Active',SYSDATETIME())
        """, r['id'], r['pid'], r['mid'], r['date'],
             r['dosage'], r['qty'], r['days'], r['ref'], r['ref'], r['sig']
        )

    def rxs_of(self, pid):
        self.cur.execute("""
            SELECT p.Prescription_ID,p.Medication_ID,
                   m.Generic_Name+' ('+m.Brand_Name+')',p.Dosage,
                   p.Quantity,p.Refills_Remaining
            FROM Prescription p
            JOIN Medication m ON m.Medication_ID=p.Medication_ID
            WHERE p.Patient_ID=? AND p.Status='Active'
        """, pid)
        return self.cur.fetchall()

    # inventory / sales
    def inv(self, mid):
        self.cur.execute("""
            SELECT i.Medication_ID,m.Generic_Name,m.Brand_Name,
                   i.Quantity,i.Unit_Price
            FROM Medication_Inventory i
            JOIN Medication m ON m.Medication_ID=i.Medication_ID
            WHERE i.Medication_ID=?
        """, mid)
        return self.cur.fetchone()

    def adjust(self, mid, dq):
        self.cur.execute(
            "UPDATE Medication_Inventory SET Quantity=Quantity+? WHERE Medication_ID=?",
            dq, mid
        )

    def inv_list(self, like):
        self.cur.execute("""
            SELECT i.Medication_ID,m.Generic_Name,m.Brand_Name,
                   i.Quantity,i.Unit_Price
            FROM Medication_Inventory i
            JOIN Medication m ON m.Medication_ID=i.Medication_ID
            WHERE (m.Generic_Name LIKE ? OR m.Brand_Name LIKE ?)
            ORDER BY m.Generic_Name
        """, like, like)
        return self.cur.fetchall()

    def upsert_med(self, mid, gen, br):
        """
        Insert new medication if it doesn't exist; otherwise update its names.
        """
        self.cur.execute("""
            MERGE Medication AS tgt
            USING (SELECT ? AS mid, ? AS gen, ? AS br) AS src
              ON tgt.Medication_ID = src.mid
            WHEN MATCHED THEN
              UPDATE SET Generic_Name = src.gen,
                         Brand_Name   = src.br
            WHEN NOT MATCHED THEN
              INSERT (Medication_ID, Generic_Name, Brand_Name, Is_Active)
              VALUES (src.mid, src.gen, src.br, 1);
        """, mid, gen, br)

    def upsert_inv(self, mid, qty, prc):
        """
        Insert or update inventory quantity and price.
        """
        self.cur.execute("""
            MERGE Medication_Inventory AS tgt
            USING (SELECT ? AS mid, ? AS qty, ? AS prc) AS src
              ON tgt.Medication_ID = src.mid
            WHEN MATCHED THEN
              UPDATE SET Quantity   = src.qty,
                         Unit_Price = src.prc
            WHEN NOT MATCHED THEN
              INSERT (Medication_ID, Quantity, Unit_Price)
              VALUES (src.mid, src.qty, src.prc);
        """, mid, qty, prc)

    def save_sale(self, cashier, pat, total, items):
        self.cur.execute(
            "INSERT INTO Sale_Header(Patient_ID,Cashier,Total) "
            "OUTPUT inserted.SaleID VALUES(?,?,?)",
            pat, cashier, total
        )
        sid = self.cur.fetchone()[0]
        for mid, qty, price in items:
            self.cur.execute(
                "INSERT INTO Sale_Item(SaleID,Medication_ID,Qty,UnitPrice)VALUES(?,?,?,?)",
                sid, mid, qty, price
            )
            self.adjust(mid, -qty)
        return sid

    def new_med_id(self):
        """Call the SP to get the next Medication_ID (e.g. 'M001')."""
        self.cur.execute("EXEC SP_GenerateNextMedicationID")
        return self.cur.fetchone()[0]

    def close(self):
        self.cn.close()

# ─────────────────────────────────────────────────────────────────────────────
#  BASE WINDOW WITH LOGOUT
# ─────────────────────────────────────────────────────────────────────────────
class RoleWin(QWidget):
    def __init__(self, login, title):
        super().__init__()
        self.login = login
        self.setWindowTitle(title)
        self.out_btn = modern_button("Logout ⏻", "danger")
        self.out_btn.clicked.connect(self.logout)

    def add_out(self, hbox: QHBoxLayout):
        hbox.addStretch()
        hbox.addWidget(self.out_btn)

    def logout(self):
        self.close()
        self.login.show()

# ─────────────────────────────────────────────────────────────────────────────
#  LOGIN WINDOW
# ─────────────────────────────────────────────────────────────────────────────
class LoginWin(QWidget):
    def __init__(self, db):
        super().__init__()
        self.db = db
        self.setWindowTitle("Hospital Login")
        self.setFixedSize(350, 220)

        lay = QVBoxLayout(self)
        lay.addWidget(banner("Hospital System"))

        self.u = nice_line("Username")
        self.p = nice_line("Password"); self.p.setEchoMode(QLineEdit.Password)
        self.msg = QLabel(); self.msg.setStyleSheet("color:red;")

        btn = modern_button("Log-in", "primary")
        btn.clicked.connect(self.go)

        for w in (self.u, self.p, self.msg, btn):
            lay.addWidget(w, alignment=Qt.AlignCenter)

    def go(self):
        role, name = self.db.login(self.u.text().strip(), self.p.text())
        if not role:
            self.msg.setText("❌ Wrong user / password")
            return

        if   role == "Intern":     self.next = Reception    (self.db, name, self)
        elif role == "Doctor":     self.next = DoctorWindow (self.db, name, self)
        elif role == "Pharmacist": self.next = Pharmacy     (self.db, name, self)
        elif role == "Manager":    self.next = Manager      (self.db, name, self)
        else:
            QMessageBox.warning(self, "Error", f"Unknown role: {role}")
            return

        self.next.show()
        self.hide()

# ─────────────────────────────────────────────────────────────────────────────
#  1.  RECEPTION  (Intern)
# ─────────────────────────────────────────────────────────────────────────────
class Reception(RoleWin):
    def __init__(self, db, who, login):
        super().__init__(login, f"Reception – {who}")
        self.db = db
        self.setMinimumSize(800, 600)

        main = QVBoxLayout(self)
        hdr  = QHBoxLayout()
        hdr.addWidget(banner("Patient Registration"))
        self.add_out(hdr)
        main.addLayout(hdr)

        # Search bar
        srch = QHBoxLayout()
        self.search_input = nice_line("Enter Patient ID or Name")
        btn_search = modern_button("Search", "primary")
        btn_search.clicked.connect(self.search_patients)
        srch.addWidget(self.search_input)
        srch.addWidget(btn_search)
        main.addLayout(srch)

        # Search results
        self.search_results = QTableWidget(0, 3)
        self.search_results.setHorizontalHeaderLabels(["Patient ID", "First Name", "Last Name"])
        self.search_results.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.search_results.cellDoubleClicked.connect(self.load_from_row)
        main.addWidget(self.search_results)

        # form -------------------------------------------------------
        form = QGridLayout()
        self.pid  = nice_line("Patient ID")
        self.fst  = nice_line(); self.lst = nice_line()
        self.dob  = nice_line("YYYY-MM-DD")
        self.gen  = QComboBox(); self.gen.addItems(["M","F","O"])
        self.mail = nice_line("email@host.com")

        for r,(lbl,w) in enumerate([
            ("Patient ID",  self.pid),
            ("First name",  self.fst),
            ("Last name",   self.lst),
            ("Date of birth",self.dob),
            ("Gender",      self.gen),
            ("Email",       self.mail),
        ]):
            form.addWidget(QLabel(lbl), r, 0)
            form.addWidget(w, r, 1)

        # doctor choice ----------------------------------------
        self.sp  = QComboBox(); self.sp.addItems(db.specs())
        self.sp.currentTextChanged.connect(lambda sp: self.fill_docs(sp))
        self.doc = QComboBox()
        self.fill_docs(self.sp.currentText())

        form.addWidget(QLabel("Specialisation"), 6, 0)
        form.addWidget(self.sp,               6, 1)
        form.addWidget(QLabel("Doctor"),       7, 0)
        form.addWidget(self.doc,              7, 1)

        main.addLayout(form)

        # buttons ----------------------------------------------------
        row = QHBoxLayout()
        badd  = modern_button("Add ⏎",      "success"); badd .clicked.connect(self.add)
        bupd  = modern_button("Update ✎",   "primary"); bupd .clicked.connect(self.upd)
        bslip = modern_button("Print Visit Slip 🖶","primary"); bslip.clicked.connect(self.slip)
        for b in (badd, bupd, bslip): row.addWidget(b)
        row.addStretch()
        main.addLayout(row)

    def search_patients(self):
        text = self.search_input.text().strip()
        if not text:
            return

        like = f"%{text}%"
        self.db.cur.execute(
            """
            SELECT Patient_ID, First_Name, Last_Name
            FROM Patient
            WHERE Is_Active = 1 AND (
                Patient_ID LIKE ? OR First_Name LIKE ? OR Last_Name LIKE ?)
            ORDER BY Created_Date DESC
            """, like, like, like
        )
        rows = self.db.cur.fetchall()

        self.search_results.setRowCount(len(rows))
        for r, row in enumerate(rows):
            for c, val in enumerate(row):
                self.search_results.setItem(r, c, QTableWidgetItem(str(val)))

    def load_from_row(self, row, _):
        pid = self.search_results.item(row, 0).text()
        rec = self.db.get_pat(pid)
        if not rec:
            QMessageBox.warning(self, "Error", "Could not load patient")
            return
        self.pid.setText(rec.Patient_ID)
        self.fst.setText(rec.First_Name)
        self.lst.setText(rec.Last_Name)
        self.dob.setText(rec.DOB)
        self.mail.setText(rec.Email)
        self.gen.setCurrentText(rec.Gender)

    def fill_docs(self, sp):
        self.doc.clear()
        for d in self.db.docs_by_spec(sp):
            self.doc.addItem(f"{d.Full_Name}  (Room {d.Room_No})")

    def collect(self):
        pid = self.pid.text().strip()
        if not pid:
            pid = self.db.new_pid()
        return {
            'id': pid,
            'first': self.fst.text().strip(),
            'last':  self.lst.text().strip(),
            'dob':   self.dob.text().strip(),
            'gender':self.gen.currentText(),
            'email': self.mail.text().strip()
        }

    def add(self):
        if self.pid.text().strip():
            QMessageBox.warning(self, "Auto-ID", "No ID needed when adding. It will be auto-generated.")
            return

        p = self.collect()
        if not p['first'] or not p['last']:
            QMessageBox.warning(self, "Missing", "First/Last name required")
            return
        try:
            datetime.strptime(p['dob'], "%Y-%m-%d")
        except:
            QMessageBox.warning(self, "Bad date", "Use YYYY-MM-DD")
            return

        self.db.add_pat(p)
        self.pid.setText(p['id'])
        QMessageBox.information(self, "OK", f"Patient {p['id']} added ✔")

    def upd(self):
        if not self.pid.text():
            QMessageBox.warning(self, "ID?", "Load a patient first")
            return
        if self.db.upd_pat(self.collect()):
            QMessageBox.information(self, "Saved", "Patient updated ✔")
        else:
            QMessageBox.warning(self, "Err", "ID invalid or inactive")

    def slip(self):
        if not self.pid.text():
            QMessageBox.warning(self, "No ID", "Add or load patient first")
            return
        spec     = self.sp.currentText()
        doc_line = self.doc.currentText()
        lines = [
            "================ VISIT SLIP ===============",
            f"Patient ID : {self.pid.text()}",
            f"Name       : {self.fst.text()} {self.lst.text()}",
            f"Visit To   : {spec}",
            f"Doctor     : {doc_line}",
            "==========================================="
        ]
        QMessageBox.information(self, "Visit Slip", "\n".join(lines))

class DoctorWindow(RoleWin):
    def __init__(self, db, who, login):
        super().__init__(login, f"Doctor – {who}")
        self.db, self.who = db, who
        self.setMinimumSize(1000, 600)

        # ─── split layout: left = work area, right = history ─────────────
        outer = QHBoxLayout(self)
        left, right = QVBoxLayout(), QVBoxLayout()
        outer.addLayout(left, 2)
        outer.addLayout(right, 1)

        # ─── header + logout ─────────────────────────────────────────────
        hdr = QHBoxLayout()
        hdr.addWidget(banner("Doctor Desk"))
        self.add_out(hdr)
        left.addLayout(hdr)

        # ─── patient search ──────────────────────────────────────────────
        top = QHBoxLayout()
        self.search_id = nice_line("Patient ID")
        btn_load = modern_button("Load ➜", "primary")
        btn_load.clicked.connect(self.load_patient)
        for w in (QLabel("Patient ID:"), self.search_id, btn_load):
            top.addWidget(w)
        top.addStretch()
        left.addLayout(top)

        self.patient_box = QLabel("No patient loaded")
        self.patient_box.setStyleSheet(
            "border:1px solid #aaa; padding:6px; font-style:italic;")
        left.addWidget(self.patient_box)

        # ─── medication search ───────────────────────────────────────────
        medgrp = QGroupBox("Search medication and pick")
        mlay = QVBoxLayout(medgrp)
        mbar = QHBoxLayout()
        self.med_srch = nice_line("generic / brand name")
        btn_find = modern_button("Search 🔍", "secondary")
        btn_find.clicked.connect(self.med_search)
        mbar.addWidget(self.med_srch)
        mbar.addWidget(btn_find)
        mbar.addStretch()
        mlay.addLayout(mbar)

        self.tbl_med = QTableWidget(0, 4)
        self.tbl_med.setHorizontalHeaderLabels(["Generic", "Brand", "ID", "Stock"])
        self.tbl_med.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.tbl_med.cellDoubleClicked.connect(self.pick_med)
        mlay.addWidget(self.tbl_med)
        left.addWidget(medgrp)

        # ─── prescription form ───────────────────────────────────────────
        formgrp = QGroupBox("New prescription")
        form = QGridLayout(formgrp)
        self.med_id  = nice_line(); self.med_id.setReadOnly(True)
        self.dosage  = nice_line("e.g. 250 mg q8h")
        self.qty     = spin(1, 1000)
        self.days    = spin(1, 90)
        self.refill  = spin(0, 12)
        self.sig     = nice_line("special instructions")

        fields = [
            ("Medication ID", self.med_id),
            ("Dosage",        self.dosage),
            ("Quantity",      self.qty),
            ("Days supply",   self.days),
            ("Refills auth",  self.refill),
            ("Instructions",  self.sig),
        ]
        for i, (lbl, w) in enumerate(fields):
            form.addWidget(QLabel(lbl), i, 0)
            form.addWidget(w, i, 1)

        btn_save = modern_button("Save prescription 💾", "success")
        btn_save.clicked.connect(self.save_rx)
        form.addWidget(btn_save, len(fields), 0, 1, 2)

        left.addWidget(formgrp)

        # ─── prescription history + print ───────────────────────────────
        right.addWidget(banner("Previous prescriptions"))
        self.tbl_hist = QTableWidget(0, 6)
        self.tbl_hist.setHorizontalHeaderLabels(
            ["Rx ID", "Med ID", "Name", "Dosage", "Qty", "Refills"])
        self.tbl_hist.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        right.addWidget(self.tbl_hist)

        btn_print = modern_button("Generate patient form 🖶", "primary")
        btn_print.clicked.connect(self.generate_form)
        right.addWidget(btn_print, alignment=Qt.AlignLeft)


    def load_patient(self):
        pid = self.search_id.text().strip()
        row = self.db.get_pat(pid)
        if not row:
            QMessageBox.warning(self, "Not found", "No active patient with that ID")
            return
        self.patient_id = pid
        self.patient_box.setText(
            f"<b>{row.Patient_ID}</b> — {row.First_Name} {row.Last_Name}, "
            f"DOB {row.DOB}, {row.Gender}<br>Email {row.Email}"
        )
        self.refresh_history()


    def med_search(self):
        rows = self.db.med_search(self.med_srch.text().strip())
        if not rows:
            QMessageBox.information(self, "Not available",
                                    "No medication with that name is in stock.")
            return
        self.tbl_med.setRowCount(len(rows))
        for r, rec in enumerate(rows):
            for c, val in enumerate(rec):
                self.tbl_med.setItem(r, c, QTableWidgetItem(str(val)))


    def pick_med(self, row, _col):
        self.med_id.setText(self.tbl_med.item(row, 2).text())
        self.dosage.setFocus()


    def save_rx(self):
        if not getattr(self, "patient_id", None):
            QMessageBox.warning(self, "No patient", "Load patient first")
            return
        if not self.med_id.text():
            QMessageBox.warning(self, "Medication", "Pick a medication first")
            return

        pr = {
            'id':     self.db.new_rxid(),
            'pid':    self.patient_id,
            'mid':    self.med_id.text(),
            'date':   datetime.now().strftime("%Y-%m-%d"),
            'dosage': self.dosage.text().strip(),
            'qty':    self.qty.value(),
            'days':   self.days.value(),
            'ref':    self.refill.value(),
            'sig':    self.sig.text().strip()
        }

        try:
            # note: exactly TEN markers here to match ten values below
            self.db.cur.execute("""
                INSERT INTO Prescription
                  (Prescription_ID,Patient_ID,Medication_ID,Prescription_Date,
                   Dosage,Quantity,Days_Supply,Refills_Authorized,Refills_Remaining,
                   Instructions,Status,Created_Date)
                VALUES(?,?,?,?,?,?,?,?,? ,?,'Active',SYSDATETIME())
            """,
            pr['id'], pr['pid'], pr['mid'], pr['date'],
            pr['dosage'], pr['qty'], pr['days'], pr['ref'], pr['ref'], pr['sig']
            )
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to save: {e}")
            return

        QMessageBox.information(self, "Saved",
                                f"Prescription {pr['id']} stored ✔")
        self.clear_form()
        self.refresh_history()


    def clear_form(self):
        for w in (self.med_id, self.dosage):
            w.clear()
        self.qty.setValue(1)
        self.days.setValue(1)
        self.refill.setValue(0)
        self.sig.clear()


    def refresh_history(self):
        rows = self.db.rxs_of(self.patient_id)
        self.tbl_hist.setRowCount(len(rows))
        for r, rec in enumerate(rows):
            for c, val in enumerate(rec):
                self.tbl_hist.setItem(r, c, QTableWidgetItem(str(val)))


    def generate_form(self):
        if not getattr(self, "patient_id", None):
            QMessageBox.warning(self, "Load patient", "No patient selected")
            return

        # re-query directly so you always get the latest data
        self.db.cur.execute("""
            SELECT p.Prescription_ID,
                   m.Generic_Name+' ('+m.Brand_Name+')' AS MedName,
                   p.Dosage, p.Quantity, p.Refills_Remaining
              FROM Prescription p
              JOIN Medication m ON m.Medication_ID=p.Medication_ID
             WHERE p.Patient_ID=? AND p.Status='Active'
             ORDER BY p.Created_Date DESC
        """, self.patient_id)

        lines = [
            "===================================================",
            f" Doctor: {self.who}",
            f" Patient ID: {self.patient_id}",
            "---------------------------------------------------"
        ]
        for pid, name, dosage, qty, ref in self.db.cur.fetchall():
            lines.append(f"{pid}  {name}  {dosage}  Qty:{qty}  Refills:{ref}")
        lines.append("===================================================")

        dlg = QMessageBox(self)
        dlg.setWindowTitle("Prescription form preview")
        dlg.setTextFormat(Qt.PlainText)
        dlg.setText("\n".join(lines))
        dlg.setStandardButtons(QMessageBox.Ok)
        dlg.exec_()


# ─────────────────────────────────────────────────────────────────────────────
#  3.  PHARMACY (Pharmacist)
# ─────────────────────────────────────────────────────────────────────────────

class Pharmacy(RoleWin):
    def __init__(self, db, who, login):
        super().__init__(login, f"Pharmacy – {who}")
        self.db      = db
        self.cashier = who
        self.cart    = []  # (med_id, name, qty, unit_price, line_total)
        self.patient_id = None
        self.patient_name = None

        self.setMinimumSize(980, 600)
        main = QVBoxLayout(self)

        # Header + Logout
        hdr = QHBoxLayout()
        hdr.addWidget(banner("Pharmacist Counter"))
        self.add_out(hdr)
        main.addLayout(hdr)

        tabs = QTabWidget()
        main.addWidget(tabs)

        # Walk-in tab
        walk = QWidget(); wl = QVBoxLayout(walk)
        wl.addWidget(QLabel("<b>Walk-in customer</b> – search meds"))
        sb = QHBoxLayout()
        self.w_srch = nice_line("generic / brand")
        btn_w_search = modern_button("Search 🔍", "primary")
        btn_w_search.clicked.connect(self._walkin_search)
        sb.addWidget(self.w_srch); sb.addWidget(btn_w_search); sb.addStretch()
        wl.addLayout(sb)
        self.tbl_w = QTableWidget(0,5)
        self.tbl_w.setHorizontalHeaderLabels(["Generic","Brand","ID","Stock","Unit Price"])
        self.tbl_w.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.tbl_w.cellClicked.connect(self._on_walkin_select)
        wl.addWidget(self.tbl_w)
        hb = QHBoxLayout()
        hb.addWidget(QLabel("Qty:")); self.w_qty = spin(1,1); self.w_qty.setEnabled(False)
        btn_w_add = modern_button("Add to cart ➕", "success")
        btn_w_add.clicked.connect(self._add_walkin)
        hb.addWidget(self.w_qty); hb.addWidget(btn_w_add); hb.addStretch()
        wl.addLayout(hb)
        tabs.addTab(walk, "Walk-in")

        # Hospital tab
        hosp = QWidget(); hl = QVBoxLayout(hosp)
        hl.addWidget(QLabel("<b>Hospital patient</b> – load Rx or search meds"))

        # Patient lookup
        ph = QHBoxLayout()
        self.h_pid = nice_line("Patient ID"); btn_load = modern_button("Load Patient", "primary")
        btn_load.clicked.connect(self._load_patient)
        ph.addWidget(self.h_pid); ph.addWidget(btn_load); ph.addStretch()
        hl.addLayout(ph)
        self.patient_box = QLabel("No patient loaded")
        self.patient_box.setStyleSheet("border:1px solid #aaa; padding:6px; font-style:italic;")
        hl.addWidget(self.patient_box)

        # Prescription history
        self.tbl_rx = QTableWidget(0,6)
        self.tbl_rx.setHorizontalHeaderLabels(["Rx ID","Med ID","Name","Dosage","Qty","Refills"])
        self.tbl_rx.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.tbl_rx.cellClicked.connect(self._on_rx_select)
        hl.addWidget(self.tbl_rx)
        btn_rx_add = modern_button("Add Rx to cart ➕", "success")
        btn_rx_add.clicked.connect(self._add_rx)
        hl.addWidget(btn_rx_add, alignment=Qt.AlignLeft)

        # Medication search for hospital
        mh = QHBoxLayout()
        self.h_srch = nice_line("Search Medications")
        btn_h_search = modern_button("Search Meds 🔍", "primary")
        btn_h_search.clicked.connect(self._hospital_med_search)
        mh.addWidget(self.h_srch); mh.addWidget(btn_h_search); mh.addStretch()
        hl.addLayout(mh)
        self.tbl_h = QTableWidget(0,5)
        self.tbl_h.setHorizontalHeaderLabels(["Generic","Brand","ID","Stock","Unit Price"])
        self.tbl_h.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.tbl_h.cellClicked.connect(self._on_hosp_select)
        hl.addWidget(self.tbl_h)
        btn_h_add = modern_button("Add Med to cart ➕", "success")
        btn_h_add.clicked.connect(self._add_hosp_med)
        hl.addWidget(btn_h_add, alignment=Qt.AlignLeft)

        tabs.addTab(hosp, "Hospital")

        # Cart + Checkout
        main.addWidget(QLabel("<b>Current Cart</b>"))
        self.tbl_cart = QTableWidget(0,5)
        self.tbl_cart.setHorizontalHeaderLabels(["Med ID","Name","Qty","Unit Price","Line Total"])
        self.tbl_cart.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        main.addWidget(self.tbl_cart)

        ft = QHBoxLayout()
        self.lbl_total = QLabel("Total: 0.00"); self.lbl_total.setStyleSheet("font-size:18px;")
        btn_co = modern_button("Checkout 💰", "success"); btn_co.clicked.connect(self._do_checkout)
        ft.addWidget(self.lbl_total); ft.addStretch(); ft.addWidget(btn_co)
        main.addLayout(ft)

    def _walkin_search(self):
        rows = self.db.med_search(self.w_srch.text().strip())
        self.tbl_w.setRowCount(len(rows))
        for r,(g,b,i,stk) in enumerate(rows):
            price = self.db.inv(i).Unit_Price
            for c,v in enumerate((g,b,i,stk,price)):
                self.tbl_w.setItem(r,c,QTableWidgetItem(str(v)))
        self.w_qty.setEnabled(False)

    def _on_walkin_select(self, row, _):
        stk = int(self.tbl_w.item(row,3).text())
        self._sel_mid   = self.tbl_w.item(row,2).text()
        self._sel_name  = f"{self.tbl_w.item(row,0).text()} ({self.tbl_w.item(row,1).text()})"
        self._sel_price = Decimal(self.tbl_w.item(row,4).text())
        self.w_qty.setRange(1, stk); self.w_qty.setValue(1); self.w_qty.setEnabled(True)

    def _add_walkin(self):
        if not hasattr(self, "_sel_mid"):
            QMessageBox.warning(self, "No selection", "Pick a med first")
            return
        line = self.w_qty.value() * self._sel_price
        self.cart.append((self._sel_mid, self._sel_name, self.w_qty.value(), self._sel_price, line))
        self._refresh_cart()

    def _load_patient(self):
        pid = self.h_pid.text().strip()
        rec = self.db.get_pat(pid)
        if not rec:
            QMessageBox.warning(self, "Not found", "No active patient with that ID")
            return
        self.patient_id = rec.Patient_ID
        self.patient_name = f"{rec.First_Name} {rec.Last_Name}"
        self.patient_box.setText(f"<b>{self.patient_id}</b> — {self.patient_name}")
        # load prescriptions
        rows = self.db.rxs_of(self.patient_id)
        self.tbl_rx.setRowCount(len(rows))
        for r, rec in enumerate(rows):
            for c, val in enumerate(rec):
                self.tbl_rx.setItem(r,c,QTableWidgetItem(str(val)))
        self._rx_sel = None

    def _on_rx_select(self, row, _):
        mid = self.tbl_rx.item(row,1).text()
        qty = int(self.tbl_rx.item(row,4).text())
        inv = self.db.inv(mid)
        if not inv or inv.Unit_Price is None:
            QMessageBox.warning(self, "Inventory Missing", "No price info available.")
            self._rx_sel = None; return
        self._rx_sel = {"rx_id":self.tbl_rx.item(row,0).text(),"mid":mid,
                        "name":f"{inv.Generic_Name} ({inv.Brand_Name})",
                        "qty":qty,"price":Decimal(inv.Unit_Price)}

    def _add_rx(self):
        if not getattr(self, "_rx_sel", None):
            QMessageBox.warning(self, "No Rx", "Select a prescription first")
            return
        s = self._rx_sel
        # check refills
        self.db.cur.execute("SELECT Refills_Remaining FROM Prescription WHERE Prescription_ID=?", s["rx_id"])
        if not self.db.cur.fetchone()[0]:
            QMessageBox.warning(self, "No Refills", "No refills remaining."); return
        line = s["qty"] * s["price"]
        self.cart.append((s["mid"], s["name"], s["qty"], s["price"], line))
        self.db.cur.execute("UPDATE Prescription SET Refills_Remaining=Refills_Remaining-1 WHERE Prescription_ID=?", s["rx_id"])
        self._refresh_cart()

    def _hospital_med_search(self):
        rows = self.db.med_search(self.h_srch.text().strip())
        self.tbl_h.setRowCount(len(rows))
        for r,(g,b,i,stk) in enumerate(rows):
            price = self.db.inv(i).Unit_Price
            for c,v in enumerate((g,b,i,stk,price)):
                self.tbl_h.setItem(r,c,QTableWidgetItem(str(v)))

    def _on_hosp_select(self, row, _):
        stk = int(self.tbl_h.item(row,3).text()); self._h_mid = self.tbl_h.item(row,2).text()
        self._h_price = Decimal(self.tbl_h.item(row,4).text()); self._h_qty = 1

    def _add_hosp_med(self):
        if not getattr(self, '_h_mid', None) or not self.patient_id:
            QMessageBox.warning(self, "Select", "Load patient and pick a med first")
            return
        line = self._h_qty * self._h_price
        self.cart.append((self._h_mid, self.patient_name, self._h_qty, self._h_price, line))
        self._refresh_cart()

    def _refresh_cart(self):
        total = Decimal(0)
        self.tbl_cart.setRowCount(len(self.cart))
        for r,line in enumerate(self.cart):
            for c,v in enumerate(line): self.tbl_cart.setItem(r,c,QTableWidgetItem(str(v)))
            total += line[-1]
        self.lbl_total.setText(f"Total: {total:.2f}")

    def _do_checkout(self):
        pid = self.patient_id or 'Walk-in'; name = self.patient_name or 'Walk-in'
        total = Decimal(self.lbl_total.text().split(':')[1])
        items = [(m,q,p) for m,_,q,p,_ in self.cart]
        sid = self.db.save_sale(self.cashier, pid, total, items)
        lines = ["============== RECEIPT ==============",
                 f"Cashier  : {self.cashier}", f"Date     : {datetime.now():%Y-%m-%d %H:%M}",
                 "-------------------------------------"]
        for _,n,qty,unit,line in self.cart: lines.append(f"{n} x{qty} @ {unit:.2f} = {line:.2f}")
        lines += ["-------------------------------------", f"Total: {total:.2f}", "====================================="]
        QMessageBox.information(self, "Receipt", "\n".join(lines))
        self.cart.clear(); self._refresh_cart()




# ─────────────────────────────────────────────────────────────────────────────
#  4.  INVENTORY (Manager)
# ─────────────────────────────────────────────────────────────────────────────
class Manager(RoleWin):
    def __init__(self, db, who, login):
        super().__init__(login, f"Inventory – {who}")
        self.db = db
        self.setWindowTitle(f"Inventory – {who}")
        self.setMinimumSize(820, 520)

        main = QVBoxLayout(self)

        # ─── Header + Logout ─────────────────────────────────────────────
        hdr = QHBoxLayout()
        hdr.addWidget(banner("Medication Inventory"))
        hdr.addStretch()
        # `add_out` comes from RoleWin to hook up the logout button
        self.add_out(hdr)
        main.addLayout(hdr)

        # ─── Search Bar ─────────────────────────────────────────────────
        search_row = QHBoxLayout()
        self.srch = nice_line("generic / brand")
        btn_search = modern_button("Search", "primary")
        btn_search.clicked.connect(self.refresh)
        search_row.addWidget(self.srch)
        search_row.addWidget(btn_search)
        search_row.addStretch()
        main.addLayout(search_row)

        # ─── Inventory Table ────────────────────────────────────────────
        self.tbl = QTableWidget(0, 5)
        self.tbl.setHorizontalHeaderLabels(
            ["Med ID", "Generic", "Brand", "Qty", "Price"]
        )
        self.tbl.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.tbl.cellClicked.connect(self.fill)
        main.addWidget(self.tbl)

        # ─── Form ───────────────────────────────────────────────────────
        form = QGridLayout()
        self.mid = nice_line("leave blank → new med")
        self.gen = nice_line("generic name")
        self.br  = nice_line("brand name")
        self.qty = spin(0, 5000)
        self.prc = nice_line("0.00")

        form.addWidget(QLabel("Med ID"),    0, 0); form.addWidget(self.mid, 0, 1)
        form.addWidget(QLabel("Generic"),   1, 0); form.addWidget(self.gen, 1, 1)
        form.addWidget(QLabel("Brand"),     2, 0); form.addWidget(self.br,  2, 1)
        form.addWidget(QLabel("Qty"),       1, 2); form.addWidget(self.qty, 1, 3)
        form.addWidget(QLabel("Price"),     2, 2); form.addWidget(self.prc, 2, 3)

        main.addLayout(form)

        # ─── Buttons ────────────────────────────────────────────────────
        btn_row = QHBoxLayout()
        btn_add   = modern_button("Add New Med + Inventory", "success")
        btn_update= modern_button("Update Inventory",       "primary")
        btn_add.clicked.connect(self.add_new_med)
        btn_update.clicked.connect(self.update_inventory)
        btn_row.addWidget(btn_add)
        btn_row.addWidget(btn_update)
        btn_row.addStretch()
        main.addLayout(btn_row)

        # initial load
        self.refresh()

    def refresh(self):
        """Reload the inventory list."""
        rows = self.db.inv_list(f"%{self.srch.text().strip()}%")
        self.tbl.setRowCount(len(rows))
        for r, row in enumerate(rows):
            for c, v in enumerate(row):
                self.tbl.setItem(r, c, QTableWidgetItem(str(v)))

    def fill(self, row, _):
        """Populate the form from the selected table row."""
        self.mid.setText(self.tbl.item(row,0).text())
        self.gen.setText(self.tbl.item(row,1).text())
        self.br .setText(self.tbl.item(row,2).text())
        self.qty.setValue(int(self.tbl.item(row,3).text()))
        self.prc.setText(self.tbl.item(row,4).text())

    def add_new_med(self):
        """Add a new medication + initial inventory. Med ID field must be blank."""
        if self.mid.text().strip():
            QMessageBox.warning(
                self, "Cannot Add",
                "To add a new medication, clear the Medication ID field first."
            )
            return

        gen, br = self.gen.text().strip(), self.br.text().strip()
        try:
            price = Decimal(self.prc.text().strip())
        except:
            QMessageBox.warning(self, "Price", "Enter a valid price")
            return
        qty = self.qty.value()
        if not gen or not br:
            QMessageBox.warning(self, "Data", "Generic & Brand are required")
            return

        # 1) generate new ID
        new_mid = self.db.new_med_id()
        self.mid.setText(str(new_mid))

        # 2) insert into Medication
        self.db.cur.execute(
            "INSERT INTO Medication(Medication_ID,Generic_Name,Brand_Name,Is_Active) "
            "VALUES(?,?,?,1)",
            new_mid, gen, br
        )

        # 3) insert initial inventory
        self.db.cur.execute(
            "INSERT INTO Medication_Inventory(Medication_ID,Quantity,Unit_Price) "
            "VALUES(?,?,?)",
            new_mid, qty, price
        )

        QMessageBox.information(self, "Saved",
                                f"New medication added with ID {new_mid}")
        self.refresh()
        # clear details for next entry
        self.gen.clear(); self.br.clear()
        self.qty.setValue(0); self.prc.clear()

    def update_inventory(self):
        mid = self.mid.text().strip()
        if not mid:
            QMessageBox.warning(self, "No ID", "Select a Med ID first.")
            return
        gen, br = self.gen.text().strip(), self.br.text().strip()
        try:
            price = Decimal(self.prc.text().strip())
        except:
            QMessageBox.warning(self, "Price", "Enter valid price")
            return
        qty = self.qty.value()

        # ensure med exists
        self.db.cur.execute("SELECT 1 FROM Medication WHERE Medication_ID=?", mid)
        if not self.db.cur.fetchone():
            QMessageBox.warning(self, "Missing", f"Med {mid} not found.")
            return

        # try-catch so window doesn't close
        try:
            self.db.upsert_med(mid, gen, br)
            self.db.upsert_inv(mid, qty, price)
        except Exception as e:
            QMessageBox.critical(self, "Update Error", f"Failed to update: {e}")
            return

        QMessageBox.information(self, "Saved", f"Medication {mid} updated ✔")
        self.refresh()



# ─────────────────────────────────────────────────────────────────────────────
def main():
    app   = QApplication(sys.argv)
    db    = DB()
    login = LoginWin(db)
    login.show()
    app.exec_()
    db.close()

if __name__ == "__main__":
    main()
