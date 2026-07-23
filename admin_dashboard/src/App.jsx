import { useEffect, useMemo, useState } from 'react';
import {
  BarChart3,
  Bell,
  Bug,
  CalendarDays,
  CheckCircle2,
  CircleDollarSign,
  ExternalLink,
  Eye,
  FileText,
  Lock,
  LogOut,
  RefreshCcw,
  Search,
  Send,
  ShieldCheck,
  Trash2,
  TrendingDown,
  TrendingUp,
  Unlock,
  UserCog,
  Users,
  Wallet,
  X,
} from 'lucide-react';
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  onSnapshot,
  serverTimestamp,
  updateDoc,
} from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import {
  deleteObject,
  ref,
} from 'firebase/storage';

import { auth, db, functions, storage } from './firebase';

const currency = new Intl.NumberFormat('vi-VN', {
  style: 'currency',
  currency: 'VND',
  maximumFractionDigits: 0,
});

const chartPalette = ['#00796b', '#d43d3d', '#2f5f9f', '#b88400', '#6d5dd3', '#5a6f69'];

const reportRangeOptions = [
  { value: 'thisMonth', label: 'Tháng này' },
  { value: 'last3', label: '3 tháng' },
  { value: 'last6', label: '6 tháng' },
  { value: 'year', label: 'Năm nay' },
  { value: 'all', label: 'Tất cả' },
  { value: 'custom', label: 'Tùy chọn' },
];

function App() {
  const [authState, setAuthState] = useState({
    loading: true,
    user: null,
    profile: null,
    isAdmin: false,
  });

  useEffect(() => {
    return onAuthStateChanged(auth, async (user) => {
      if (!user) {
        setAuthState({
          loading: false,
          user: null,
          profile: null,
          isAdmin: false,
        });
        return;
      }

      try {
        const profileSnap = await getDoc(doc(db, 'users', user.uid));
        const profile = profileSnap.exists()
          ? { id: profileSnap.id, ...profileSnap.data() }
          : null;

        setAuthState({
          loading: false,
          user,
          profile,
          isAdmin: profile?.role === 'admin',
        });
      } catch (error) {
        setAuthState({
          loading: false,
          user,
          profile: null,
          isAdmin: false,
          error: error.message,
        });
      }
    });
  }, []);

  if (authState.loading) {
    return <FullPageState title="Đang kiểm tra phiên đăng nhập..." />;
  }

  if (!authState.user) {
    return <LoginScreen />;
  }

  if (!authState.isAdmin) {
    return (
      <AccessDenied
        email={authState.user.email}
        error={authState.error}
        onSignOut={() => signOut(auth)}
      />
    );
  }

  return (
    <AdminDashboard
      adminProfile={authState.profile}
      onSignOut={() => signOut(auth)}
    />
  );
}

function LoginScreen() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleSubmit(event) {
    event.preventDefault();
    setError('');
    setLoading(true);
    try {
      await signInWithEmailAndPassword(auth, email.trim(), password);
    } catch (err) {
      setError(firebaseAuthMessage(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="auth-shell">
      <section className="auth-card">
        <div className="brand-mark">
          <ShieldCheck size={30} />
        </div>
        <h1>Smart Expense Admin</h1>
        <p>Đăng nhập bằng tài khoản đã được gán role admin trong Firestore.</p>

        <form onSubmit={handleSubmit} className="login-form">
          <label>
            Email
            <input
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              placeholder="admin@email.com"
              type="email"
              required
            />
          </label>
          <label>
            Mật khẩu
            <input
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              placeholder="••••••••"
              type="password"
              required
            />
          </label>
          {error && <div className="error-box">{error}</div>}
          <button disabled={loading} className="primary-button">
            {loading ? 'Đang đăng nhập...' : 'Đăng nhập Admin'}
          </button>
        </form>
      </section>
    </main>
  );
}

function AccessDenied({ email, error, onSignOut }) {
  return (
    <main className="auth-shell">
      <section className="auth-card">
        <div className="brand-mark danger">
          <Lock size={28} />
        </div>
        <h1>Chưa có quyền admin</h1>
        <p>
          Tài khoản <strong>{email}</strong> đã đăng nhập nhưng chưa có field{' '}
          <code>role: "admin"</code> trong Firestore.
        </p>
        {error && <div className="error-box">{error}</div>}
        <button className="secondary-button" onClick={onSignOut}>
          Đăng xuất
        </button>
      </section>
    </main>
  );
}

function AdminDashboard({ adminProfile, onSignOut }) {
  const [usersData, setUsersData] = useState([]);
  const [transactions, setTransactions] = useState([]);
  const [budgets, setBudgets] = useState([]);
  const [documents, setDocuments] = useState([]);
  const [bugReports, setBugReports] = useState([]);
  const [campaigns, setCampaigns] = useState([]);
  const [campaignRecipients, setCampaignRecipients] = useState([]);
  const [activeView, setActiveView] = useState('overview');
  const [selectedUserId, setSelectedUserId] = useState('');
  const [queryText, setQueryText] = useState('');
  const [reportPreset, setReportPreset] = useState('last6');
  const [reportStartDate, setReportStartDate] = useState('');
  const [reportEndDate, setReportEndDate] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    setLoading(true);
    const unsubscribers = [];

    unsubscribers.push(
      onSnapshot(
        collection(db, 'users'),
        (snapshot) => {
          const nextUsers = snapshot.docs
            .map((item) => normalizeUser(item))
            .sort((a, b) => b.createdAtMs - a.createdAtMs);
          setUsersData(nextUsers);
          setSelectedUserId((current) => current || nextUsers[0]?.id || '');
          setLoading(false);
        },
        (err) => {
          setError(firestoreMessage(err));
          setLoading(false);
        },
      ),
    );

    unsubscribers.push(
      onSnapshot(
        collectionGroup(db, 'transactions'),
        (snapshot) => {
          setTransactions(
            snapshot.docs
              .map((item) => normalizeTransaction(item))
              .sort((a, b) => b.transactionDateMs - a.transactionDateMs),
          );
        },
        (err) => setError(firestoreMessage(err)),
      ),
    );

    unsubscribers.push(
      onSnapshot(
        collectionGroup(db, 'budgets'),
        (snapshot) => {
          setBudgets(snapshot.docs.map((item) => normalizeBudget(item)));
        },
        (err) => setError(firestoreMessage(err)),
      ),
    );

    unsubscribers.push(
      onSnapshot(
        collection(db, 'documents'),
        (snapshot) => {
          setDocuments(
            snapshot.docs
              .map((item) => normalizeDocument(item))
              .sort((a, b) => b.createdAtMs - a.createdAtMs),
          );
        },
        (err) => setError(firestoreMessage(err)),
      ),
    );

    unsubscribers.push(
      onSnapshot(
        collection(db, 'bugReports'),
        (snapshot) => {
          setBugReports(
            snapshot.docs
              .map((item) => normalizeBugReport(item))
              .sort((a, b) => b.createdAtMs - a.createdAtMs),
          );
        },
        (err) => setError(firestoreMessage(err)),
      ),
    );

    unsubscribers.push(
      onSnapshot(
        collection(db, 'notificationCampaigns'),
        (snapshot) => {
          setCampaigns(
            snapshot.docs
              .map((item) => normalizeCampaign(item))
              .sort((a, b) => b.createdAtMs - a.createdAtMs),
          );
        },
        (err) => setError(firestoreMessage(err)),
      ),
    );

    unsubscribers.push(
      onSnapshot(
        collectionGroup(db, 'recipients'),
        (snapshot) => {
          setCampaignRecipients(
            snapshot.docs.map((item) => normalizeCampaignRecipient(item)),
          );
        },
        (err) => setError(firestoreMessage(err)),
      ),
    );

    return () => unsubscribers.forEach((unsubscribe) => unsubscribe());
  }, []);

  const appUsers = useMemo(
    () => usersData.filter((user) => user.role !== 'admin' && user.id !== adminProfile?.id),
    [usersData, adminProfile?.id],
  );

  const filteredUsers = useMemo(() => {
    const keyword = queryText.trim().toLowerCase();
    if (!keyword) return appUsers;
    return appUsers.filter((user) => {
      return [user.fullName, user.email, user.id]
        .join(' ')
        .toLowerCase()
        .includes(keyword);
    });
  }, [queryText, appUsers]);

  const selectedUser =
    appUsers.find((user) => user.id === selectedUserId) || filteredUsers[0];
  const selectedTransactions = useMemo(() => {
    return transactions.filter((item) => item.userId === selectedUser?.id);
  }, [transactions, selectedUser?.id]);
  const selectedBudgets = useMemo(() => {
    return budgets.filter((item) => item.userId === selectedUser?.id);
  }, [budgets, selectedUser?.id]);

  const systemReport = useMemo(
    () => buildReport(transactions, appUsers.length),
    [transactions, appUsers.length],
  );
  const reportRange = useMemo(
    () => resolveReportRange(reportPreset, reportStartDate, reportEndDate),
    [reportPreset, reportStartDate, reportEndDate],
  );
  const reportTransactions = useMemo(
    () => filterTransactionsByRange(transactions, reportRange),
    [transactions, reportRange.startMs, reportRange.endMs],
  );
  const filteredReport = useMemo(
    () => buildReport(reportTransactions, appUsers.length, reportRange),
    [reportTransactions, appUsers.length, reportRange.startMs, reportRange.endMs],
  );
  const userReport = useMemo(
    () => buildReport(selectedTransactions, selectedUser ? 1 : 0),
    [selectedTransactions, selectedUser],
  );
  const accountSummary = useMemo(
    () => buildAccountSummary(usersData),
    [usersData],
  );
  const userRankings = useMemo(
    () => buildUserRankings(appUsers, reportTransactions),
    [appUsers, reportTransactions],
  );
  const campaignStats = useMemo(
    () => buildCampaignStats(campaigns, campaignRecipients),
    [campaigns, campaignRecipients],
  );
  const viewTitle = {
    overview: 'Tổng quan hệ thống',
    users: 'Quản lý người dùng',
    reports: 'Báo cáo tài chính',
  }[activeView];
  const extendedViewTitle = {
    documents: 'Quản lý tài liệu PDF',
    bugs: 'Báo cáo lỗi',
    campaigns: 'Gửi thông báo',
  }[activeView] || viewTitle;

  async function updateUser(uid, updates) {
    try {
      await updateDoc(doc(db, 'users', uid), {
        ...updates,
        updatedAt: serverTimestamp(),
      });
    } catch (err) {
      setError(firestoreMessage(err));
    }
  }

  return (
    <div className="admin-shell">
      <aside className="sidebar">
        <div className="sidebar-brand">
          <div className="brand-mark small">
            <Wallet size={22} />
          </div>
          <div>
            <strong>Smart Expense</strong>
            <span>Bảng quản trị</span>
          </div>
        </div>

        <nav className="sidebar-nav">
          <button
            className={activeView === 'overview' ? 'active' : ''}
            onClick={() => setActiveView('overview')}
            type="button"
          >
            <BarChart3 size={18} />
            Tổng quan
          </button>
          <button
            className={activeView === 'users' ? 'active' : ''}
            onClick={() => setActiveView('users')}
            type="button"
          >
            <Users size={18} />
            Người dùng
          </button>
          <button
            className={activeView === 'reports' ? 'active' : ''}
            onClick={() => setActiveView('reports')}
            type="button"
          >
            <CircleDollarSign size={18} />
            Báo cáo
          </button>
          <button
            className={activeView === 'documents' ? 'active' : ''}
            onClick={() => setActiveView('documents')}
            type="button"
          >
            <FileText size={18} />
            Tài liệu
          </button>
          <button
            className={activeView === 'bugs' ? 'active' : ''}
            onClick={() => setActiveView('bugs')}
            type="button"
          >
            <Bug size={18} />
            Bug
          </button>
          <button
            className={activeView === 'campaigns' ? 'active' : ''}
            onClick={() => setActiveView('campaigns')}
            type="button"
          >
            <Bell size={18} />
            Thông báo
          </button>
        </nav>

        <div className="sidebar-footer">
          <button className="sidebar-logout" onClick={onSignOut} type="button">
            <LogOut size={18} />
            Đăng xuất
          </button>
        </div>
      </aside>

      <main className="dashboard">
        <header className="topbar">
          <div>
            <h1 className="dynamic-title">{extendedViewTitle}</h1>
            <p>Xin chào, {adminProfile?.fullName || 'Admin'}</p>
            <h1>Quản lý người dùng & báo cáo</h1>
          </div>
        </header>

        {error && (
          <div className="error-banner">
            <span>{error}</span>
            <button onClick={() => setError('')}>
              <RefreshCcw size={16} />
            </button>
          </div>
        )}

        {loading ? (
          <FullPageState title="Đang tải dữ liệu Firestore..." compact />
        ) : (
          <>
            {activeView === 'overview' && (
              <>
                <section id="overview" className="metric-grid">
              <MetricCard
                title="Tổng user"
                value={systemReport.userCount}
                icon={<Users />}
                tone="primary"
              />
              <MetricCard
                title="Tổng thu"
                value={formatVnd(systemReport.income)}
                icon={<TrendingUp />}
                tone="income"
              />
              <MetricCard
                title="Tổng chi"
                value={formatVnd(systemReport.expense)}
                icon={<TrendingDown />}
                tone="expense"
              />
              <MetricCard
                title="Số dư hệ thống"
                value={formatVnd(systemReport.balance)}
                icon={<Wallet />}
                tone="tertiary"
              />
                </section>
                <section className="overview-grid">
                  <Panel title="Trạng thái tài khoản">
                    <AccountStatus summary={accountSummary} />
                  </Panel>
                  <Panel title="Hoạt động gần đây">
                    <RecentActivity transactions={transactions} />
                  </Panel>
                </section>
              </>
            )}

            {activeView === 'reports' && (
              <div className="reports-page">
                <ReportRangeControls
                  preset={reportPreset}
                  startDate={reportStartDate}
                  endDate={reportEndDate}
                  rangeLabel={reportRange.label}
                  transactionCount={reportTransactions.length}
                  onPresetChange={setReportPreset}
                  onStartDateChange={setReportStartDate}
                  onEndDateChange={setReportEndDate}
                />
                <section id="reports" className="report-grid">
              <Panel title="Thu chi theo thời gian">
                <BarReport items={filteredReport.monthly} />
              </Panel>
              <Panel title="Top danh mục chi tiêu">
                <CategoryReport items={filteredReport.categories} />
              </Panel>
                </section>
                <section className="chart-grid">
                  <Panel title="Tỷ trọng chi tiêu">
                    <DonutChart items={filteredReport.categories} />
                  </Panel>
                  <Panel title="Xu hướng số dư">
                    <BalanceLineChart items={filteredReport.monthly} />
                  </Panel>
                </section>
                <section className="report-detail-grid">
                  <Panel title="Bảng tổng hợp theo tháng">
                    <MonthlyTable items={filteredReport.monthly} />
                  </Panel>
                  <Panel title="Người dùng chi tiêu nhiều">
                    <TopUsersTable users={userRankings} />
                  </Panel>
                </section>
              </div>
            )}

            {activeView === 'users' && (
              <UserTableView
                users={filteredUsers}
                queryText={queryText}
                onQueryChange={setQueryText}
                transactions={transactions}
                budgets={budgets}
                onUpdateUser={updateUser}
                onError={setError}
                campaigns={campaigns}
              />
            )}

            {activeView === 'documents' && (
              <DocumentsManager documents={documents} onError={setError} />
            )}

            {activeView === 'bugs' && (
              <BugReportsManager
                reports={bugReports}
                users={appUsers}
                onError={setError}
              />
            )}

            {activeView === 'campaigns' && (
              <CampaignManager
                users={appUsers}
                campaigns={campaignStats}
                onError={setError}
              />
            )}
          </>
        )}
      </main>
    </div>
  );
}

function DocumentsManager({ documents, onError }) {
  const [searchText, setSearchText] = useState('');
  const filteredDocuments = useMemo(() => {
    const keyword = searchText.trim().toLowerCase();
    if (!keyword) return documents;

    return documents.filter((item) => {
      return [
        item.title,
        item.fileName,
        item.userName,
        item.userEmail,
        item.userId,
        item.uploadedBy,
      ]
        .join(' ')
        .toLowerCase()
        .includes(keyword);
    });
  }, [documents, searchText]);

  async function removeDocument(documentItem) {
    try {
      if (documentItem.storagePath) {
        await deleteObject(ref(storage, documentItem.storagePath));
      }
      await deleteDoc(doc(db, 'documents', documentItem.id));
    } catch (err) {
      onError(firestoreMessage(err));
    }
  }

  return (
    <section className="management-grid management-grid--single">
      <Panel title="Danh sách tài liệu">
        <div className="search-box document-search">
          <Search size={18} />
          <input
            value={searchText}
            onChange={(event) => setSearchText(event.target.value)}
            placeholder="Tìm theo tên báo cáo, người xuất, email, UID..."
          />
        </div>
        <div className="admin-list">
          {documents.length === 0 ? (
            <p className="empty-text">Chưa có tài liệu PDF.</p>
          ) : filteredDocuments.length === 0 ? (
            <p className="empty-text">Không tìm thấy tài liệu phù hợp.</p>
          ) : (
            filteredDocuments.map((item) => (
              <div className="admin-row" key={item.id}>
                <FileText size={22} />
                <span>
                  <strong>{item.title || item.fileName || 'Tài liệu'}</strong>
                  <small>
                    {item.category} • {formatDate(item.createdAt || new Date())}
                  </small>
                  <small>
                    Người xuất: {item.userName || item.userEmail || item.userId || 'Không rõ'}
                  </small>
                  {item.periodLabel && <small>Kỳ thống kê: {item.periodLabel}</small>}
                </span>
                {item.fileUrl && (
                  <a className="icon-link" href={item.fileUrl} rel="noreferrer" target="_blank">
                    <ExternalLink size={18} />
                  </a>
                )}
                <button className="danger-icon-button" onClick={() => removeDocument(item)} type="button">
                  <Trash2 size={18} />
                </button>
              </div>
            ))
          )}
        </div>
      </Panel>
    </section>
  );
}

function BugReportsManager({ reports, users, onError }) {
  const [searchText, setSearchText] = useState('');
  const userById = useMemo(() => {
    return users.reduce((acc, user) => {
      acc[user.id] = user;
      return acc;
    }, {});
  }, [users]);
  const visibleReports = useMemo(() => {
    const keyword = searchText.trim().toLowerCase();
    const enrichedReports = reports.map((report) => {
      const owner = userById[report.userId];
      const userName = report.userName || owner?.fullName || '';
      const userEmail = report.userEmail || owner?.email || '';
      return { ...report, userName, userEmail };
    });

    if (!keyword) return enrichedReports;

    return enrichedReports.filter((report) => {
      return [
        report.title,
        report.description,
        report.userName,
        report.userEmail,
        report.userId,
        report.screenName,
        report.status,
        report.severity,
      ]
        .join(' ')
        .toLowerCase()
        .includes(keyword);
    });
  }, [reports, searchText, userById]);

  async function updateStatus(report, status) {
    try {
      await updateDoc(doc(db, 'bugReports', report.id), {
        status,
        updatedAt: serverTimestamp(),
      });
    } catch (err) {
      onError(firestoreMessage(err));
    }
  }

  return (
    <Panel title="Báo cáo lỗi từ mobile">
      <div className="search-box document-search">
        <Search size={18} />
        <input
          value={searchText}
          onChange={(event) => setSearchText(event.target.value)}
          placeholder="Tìm theo tên lỗi, người gửi, email, màn hình..."
        />
      </div>
      <div className="admin-list">
        {reports.length === 0 ? (
          <p className="empty-text">Chưa có bug report nào.</p>
        ) : visibleReports.length === 0 ? (
          <p className="empty-text">Không tìm thấy bug report phù hợp.</p>
        ) : (
          visibleReports.map((report) => (
            <div className="bug-row" key={report.id}>
              <div className="bug-row-heading">
                <Bug size={22} />
                <span>
                  <strong>{report.title}</strong>
                  <small>
                    Người gửi: {report.userName || report.userEmail || report.userId || 'Không rõ'}
                  </small>
                  <small>
                    {report.userEmail || report.userId} • {report.screenName || 'Không rõ'} •{' '}
                    {formatDate(report.createdAt || new Date())}
                  </small>
                </span>
                <Badge tone={bugStatusTone(report.status)}>
                  {bugStatusLabel(report.status)}
                </Badge>
              </div>
              <p>{report.description}</p>
              <div className="bug-row-actions">
                {report.imageUrl && (
                  <a className="ghost-button" href={report.imageUrl} rel="noreferrer" target="_blank">
                    <ExternalLink size={18} />
                    Xem ảnh
                  </a>
                )}
                <select
                  value={report.status}
                  onChange={(event) => updateStatus(report, event.target.value)}
                >
                  <option value="pending">Chờ xử lý</option>
                  <option value="in_progress">Đang xử lý</option>
                  <option value="resolved">Đã xử lý</option>
                  <option value="rejected">Từ chối</option>
                </select>
              </div>
            </div>
          ))
        )}
      </div>
    </Panel>
  );
}

function CampaignManager({ users, campaigns, onError }) {
  const [form, setForm] = useState({
    title: '',
    body: '',
    targetType: 'all',
    targetUserId: '',
  });
  const [loading, setLoading] = useState(false);

  async function sendCampaign(event) {
    event.preventDefault();
    setLoading(true);
    try {
      const callable = httpsCallable(functions, 'sendNotificationCampaign');
      await callable({
        title: form.title.trim(),
        body: form.body.trim(),
        type: 'campaign',
        targetType: form.targetType,
        targetUserIds:
          form.targetType === 'selected' && form.targetUserId
            ? [form.targetUserId]
            : [],
      });
      setForm({ title: '', body: '', targetType: 'all', targetUserId: '' });
    } catch (err) {
      onError(firestoreMessage(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <section className="management-grid campaign-management-grid">
      <Panel title="Gửi thông báo">
        <form className="admin-form" onSubmit={sendCampaign}>
          <label>
            Tiêu đề
            <input
              value={form.title}
              onChange={(event) => setForm({ ...form, title: event.target.value })}
              required
            />
          </label>
          <label>
            Nội dung
            <textarea
              value={form.body}
              onChange={(event) => setForm({ ...form, body: event.target.value })}
              required
              rows={4}
            />
          </label>
          <label>
            Người nhận
            <select
              value={form.targetType}
              onChange={(event) => setForm({ ...form, targetType: event.target.value })}
            >
              <option value="all">Tất cả người dùng</option>
              <option value="selected">Chọn một người dùng</option>
            </select>
          </label>
          {form.targetType === 'selected' && (
            <label>
              Người dùng
              <select
                value={form.targetUserId}
                onChange={(event) => setForm({ ...form, targetUserId: event.target.value })}
                required
              >
                <option value="">Chọn người dùng</option>
                {users.map((user) => (
                  <option key={user.id} value={user.id}>
                    {user.fullName || user.email || user.id}
                  </option>
                ))}
              </select>
            </label>
          )}
          <button className="primary-button" disabled={loading} type="submit">
            <Send size={18} />
            {loading ? 'Đang gửi...' : 'Gửi xuống máy'}
          </button>
        </form>
      </Panel>

      <Panel title="Thống kê campaign">
        <div className="admin-list">
          {campaigns.length === 0 ? (
            <p className="empty-text">Chưa có campaign nào.</p>
          ) : (
            campaigns.map((campaign) => (
              <div className="campaign-row" key={campaign.id}>
                <strong>{campaign.title}</strong>
                <p>{campaign.body}</p>
                <div className="campaign-metrics">
                  <span>Người nhận: {campaign.targetUserCount}</span>
                  <span>Gửi thành công: {campaign.sentCount}</span>
                  <span>Lỗi: {campaign.failedCount}</span>
                  <span>Đã mở: {campaign.openedCount}</span>
                  <span>Đã đọc: {campaign.readCount}</span>
                </div>
              </div>
            ))
          )}
        </div>
      </Panel>
    </section>
  );
}

function AccountStatus({ summary }) {
  const total = summary.active + summary.locked;
  const activePercent = total > 0 ? Math.round((summary.active / total) * 100) : 0;
  const lockedPercent = total > 0 ? Math.round((summary.locked / total) * 100) : 0;
  return (
    <div className="status-grid">
      <div className="status-card">
        <CheckCircle2 size={22} />
        <span>Đang hoạt động</span>
        <strong>{summary.active}</strong>
        <div className="status-bar-track">
          <div className="status-bar-fill active-fill" style={{ width: `${activePercent}%` }} />
        </div>
        <small className="status-pct">{activePercent}% tổng user</small>
      </div>
      <div className="status-card warning">
        <Lock size={22} />
        <span>Đã khóa</span>
        <strong>{summary.locked}</strong>
        <div className="status-bar-track">
          <div className="status-bar-fill locked-fill" style={{ width: `${lockedPercent}%` }} />
        </div>
        <small className="status-pct">{lockedPercent}% tổng user</small>
      </div>
      <div className="status-card info">
        <UserCog size={22} />
        <span>Quản trị viên</span>
        <strong>{summary.admins}</strong>
      </div>
      <div className="status-card muted">
        <ShieldCheck size={22} />
        <span>Đã onboarding</span>
        <strong>{summary.onboarded}</strong>
        <div className="status-bar-track">
          <div className="status-bar-fill onboard-fill" style={{ width: `${total > 0 ? Math.round((summary.onboarded / total) * 100) : 0}%` }} />
        </div>
        <small className="status-pct">{total > 0 ? Math.round((summary.onboarded / total) * 100) : 0}% tổng user</small>
      </div>
    </div>
  );
}

function ReportRangeControls({
  preset,
  startDate,
  endDate,
  rangeLabel,
  transactionCount,
  onPresetChange,
  onStartDateChange,
  onEndDateChange,
}) {
  return (
    <section className="report-filter-panel">
      <div className="report-filter-heading">
        <div className="filter-icon">
          <CalendarDays size={22} />
        </div>
        <div>
          <h2>Khoảng thời gian thống kê</h2>
          <p>
            {rangeLabel} • {transactionCount} giao dịch
          </p>
        </div>
      </div>

      <label className="range-select">
        Chọn khoảng thời gian
        <select
          value={preset}
          onChange={(event) => onPresetChange(event.target.value)}
        >
          {reportRangeOptions.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      </label>

      <div className="date-range-inputs">
        <label>
          Từ ngày
          <input
            type="date"
            value={startDate}
            onFocus={() => onPresetChange('custom')}
            onChange={(event) => {
              onPresetChange('custom');
              onStartDateChange(event.target.value);
            }}
          />
        </label>
        <label>
          Đến ngày
          <input
            type="date"
            value={endDate}
            onFocus={() => onPresetChange('custom')}
            onChange={(event) => {
              onPresetChange('custom');
              onEndDateChange(event.target.value);
            }}
          />
        </label>
      </div>
    </section>
  );
}

function RecentActivity({ transactions }) {
  const latest = transactions.slice(0, 8);
  if (latest.length === 0) {
    return <p className="empty-text">Chưa có giao dịch nào.</p>;
  }

  return (
    <div className="transaction-list">
      {latest.map((item) => (
        <div key={item.id} className="transaction-row">
          <span>
            <strong>{item.title || item.category}</strong>
            <small>
              {item.category} • {formatDate(item.transactionDate)}
            </small>
          </span>
          <strong className={item.type === 'income' ? 'income' : 'expense'}>
            {item.type === 'income' ? '+' : '-'}
            {formatVnd(item.amount)}
          </strong>
        </div>
      ))}
    </div>
  );
}

function MonthlyTable({ items }) {
  return (
    <div className="report-table">
      <div className="report-table-row heading">
        <span>Tháng</span>
        <span>Thu</span>
        <span>Chi</span>
        <span>Số dư</span>
      </div>
      {items.map((item) => (
        <div key={item.key} className="report-table-row">
          <span>{item.label}</span>
          <span className="income">{formatVnd(item.income)}</span>
          <span className="expense">{formatVnd(item.expense)}</span>
          <strong>{formatVnd(item.income - item.expense)}</strong>
        </div>
      ))}
    </div>
  );
}

function TopUsersTable({ users }) {
  if (users.length === 0) {
    return <p className="empty-text">Chưa có dữ liệu user.</p>;
  }

  return (
    <div className="report-table user-ranking-table">
      <div className="report-table-row heading">
        <span>Người dùng</span>
        <span>Giao dịch</span>
        <span>Chi tiêu</span>
      </div>
      {users.slice(0, 8).map((user) => (
        <div key={user.id} className="report-table-row">
          <span>
            <strong>{user.fullName || 'Chưa đặt tên'}</strong>
            <small>{user.email || user.id}</small>
          </span>
          <span>{user.count}</span>
          <strong className="expense">{formatVnd(user.expense)}</strong>
        </div>
      ))}
    </div>
  );
}

function UserTableView({ users, queryText, onQueryChange, transactions, budgets, onUpdateUser, onError, campaigns }) {
  const [detailUser, setDetailUser] = useState(null);
  const [notifyUser, setNotifyUser] = useState(null);
  const [savingId, setSavingId] = useState(null);

  async function toggleLock(user) {
    setSavingId(user.id);
    try {
      await onUpdateUser(user.id, { status: user.status === 'locked' ? 'active' : 'locked' });
    } finally {
      setSavingId(null);
    }
  }

  const detailTransactions = useMemo(
    () => detailUser ? transactions.filter((t) => t.userId === detailUser.id) : [],
    [transactions, detailUser?.id],
  );
  const detailBudgets = useMemo(
    () => detailUser ? budgets.filter((b) => b.userId === detailUser.id) : [],
    [budgets, detailUser?.id],
  );

  return (
    <section id="users" className="users-table-section">
      <div className="users-table-toolbar">
        <div className="search-box">
          <Search size={18} />
          <input
            value={queryText}
            onChange={(event) => onQueryChange(event.target.value)}
            placeholder="Tìm theo tên, email, UID..."
          />
        </div>
        <span className="user-count-badge">{users.length} người dùng</span>
      </div>

      <div className="users-table-wrap">
        <table className="users-table">
          <thead>
            <tr>
              <th>#</th>
              <th>Người dùng</th>
              <th>Email</th>
              <th>Trạng thái</th>
              <th>Ngày tạo</th>
              <th>Thao tác</th>
            </tr>
          </thead>
          <tbody>
            {users.length === 0 && (
              <tr>
                <td colSpan={6} className="table-empty">Không tìm thấy người dùng nào.</td>
              </tr>
            )}
            {users.map((user, index) => (
              <tr key={user.id} className={user.status === 'locked' ? 'row-locked' : ''}>
                <td className="col-index">{index + 1}</td>
                <td className="col-user">
                  <Avatar user={user} />
                  <span>
                    <strong>{user.fullName || 'Chưa đặt tên'}</strong>
                    <small>{user.id}</small>
                  </span>
                </td>
                <td className="col-email">{user.email || '—'}</td>
                <td className="col-status">
                  <Badge tone={user.status === 'locked' ? 'danger' : 'success'}>
                    {user.status === 'locked' ? 'Đã khóa' : 'Hoạt động'}
                  </Badge>
                </td>
                <td className="col-date">{user.createdAt ? formatDate(user.createdAt) : '—'}</td>
                <td className="col-actions">
                  <button
                    className="tbl-action-btn view"
                    title="Xem chi tiết"
                    onClick={() => setDetailUser(user)}
                  >
                    <Eye size={16} />
                  </button>
                  <button
                    className={`tbl-action-btn ${user.status === 'locked' ? 'unlock' : 'lock'}`}
                    title={user.status === 'locked' ? 'Mở khóa' : 'Khóa tài khoản'}
                    disabled={savingId === user.id}
                    onClick={() => toggleLock(user)}
                  >
                    {user.status === 'locked' ? <Unlock size={16} /> : <Lock size={16} />}
                  </button>
                  <button
                    className="tbl-action-btn notify"
                    title="Gửi thông báo"
                    onClick={() => setNotifyUser(user)}
                  >
                    <Bell size={16} />
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {detailUser && (
        <UserDetailModal
          user={detailUser}
          transactions={detailTransactions}
          budgets={detailBudgets}
          onUpdateUser={onUpdateUser}
          onClose={() => setDetailUser(null)}
        />
      )}

      {notifyUser && (
        <SendNotificationModal
          user={notifyUser}
          onClose={() => setNotifyUser(null)}
          onError={onError}
        />
      )}
    </section>
  );
}

function UserDetailModal({ user, transactions, budgets, onUpdateUser, onClose }) {
  const [saving, setSaving] = useState(false);
  const report = useMemo(() => buildReport(transactions, 1), [transactions]);

  async function handleUpdate(updates) {
    setSaving(true);
    try {
      await onUpdateUser(user.id, updates);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-card" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Chi tiết người dùng</h2>
          <button className="modal-close" onClick={onClose}><X size={20} /></button>
        </div>

        <div className="modal-body">
          <div className="profile-strip">
            <Avatar user={user} large />
            <div>
              <h2>{user.fullName || 'Chưa đặt tên'}</h2>
              <p>{user.email || '—'}</p>
              <small>UID: {user.id}</small>
            </div>
            <Badge tone={user.status === 'locked' ? 'danger' : 'success'}>
              {user.status === 'locked' ? 'Đã khóa' : 'Hoạt động'}
            </Badge>
          </div>

          <div className="mini-metrics">
            <MiniMetric label="Thu" value={formatVnd(report.income)} />
            <MiniMetric label="Chi" value={formatVnd(report.expense)} />
            <MiniMetric label="Số dư" value={formatVnd(report.balance)} />
            <MiniMetric label="Giao dịch" value={transactions.length} />
          </div>

          <div className="detail-actions">
            <label>
              Trạng thái tài khoản
              <select
                value={user.status || 'active'}
                disabled={saving}
                onChange={(event) => handleUpdate({ status: event.target.value })}
              >
                <option value="active">Hoạt động</option>
                <option value="locked">Đã khóa</option>
              </select>
            </label>
          </div>

          <div className="split-list">
            <div>
              <h3>Giao dịch gần đây</h3>
              <div className="transaction-list">
                {transactions.slice(0, 8).map((item) => (
                  <div key={item.id} className="transaction-row">
                    <span>
                      <strong>{item.title || item.category}</strong>
                      <small>{item.category} • {formatDate(item.transactionDate)}</small>
                    </span>
                    <strong className={item.type === 'income' ? 'income' : 'expense'}>
                      {item.type === 'income' ? '+' : '-'}{formatVnd(item.amount)}
                    </strong>
                  </div>
                ))}
                {transactions.length === 0 && (
                  <p className="empty-text">Người dùng này chưa có giao dịch.</p>
                )}
              </div>
            </div>
            <div>
              <h3>Ngân sách</h3>
              <div className="budget-list">
                {budgets.map((budget) => (
                  <div key={budget.id} className="budget-row">
                    <span>{budget.category}</span>
                    <strong>{formatVnd(budget.limitAmount)}</strong>
                  </div>
                ))}
                {budgets.length === 0 && (
                  <p className="empty-text">Chưa đặt ngân sách.</p>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function SendNotificationModal({ user, onClose, onError }) {
  const [form, setForm] = useState({ title: '', body: '' });
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  async function handleSend(event) {
    event.preventDefault();
    setLoading(true);
    try {
      const callable = httpsCallable(functions, 'sendNotificationCampaign');
      await callable({
        title: form.title.trim(),
        body: form.body.trim(),
        type: 'campaign',
        targetType: 'selected',
        targetUserIds: [user.id],
      });
      setSuccess(true);
      setTimeout(() => {
        onClose();
      }, 1500);
    } catch (err) {
      onError(firestoreMessage(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-card modal-card--sm" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Gửi thông báo</h2>
          <button className="modal-close" onClick={onClose}><X size={20} /></button>
        </div>
        <div className="modal-body">
          <div className="notify-user-target">
            <Avatar user={user} />
            <span>
              <strong>{user.fullName || 'Chưa đặt tên'}</strong>
              <small>{user.email || user.id}</small>
            </span>
          </div>

          {success ? (
            <div className="notify-success">
              <CheckCircle2 size={40} />
              <p>Đã gửi thông báo thành công!</p>
            </div>
          ) : (
            <form className="admin-form" onSubmit={handleSend}>
              <label>
                Tiêu đề
                <input
                  value={form.title}
                  onChange={(e) => setForm({ ...form, title: e.target.value })}
                  placeholder="Nhập tiêu đề thông báo..."
                  required
                />
              </label>
              <label>
                Nội dung
                <textarea
                  value={form.body}
                  onChange={(e) => setForm({ ...form, body: e.target.value })}
                  placeholder="Nhập nội dung thông báo..."
                  required
                  rows={4}
                />
              </label>
              <button className="primary-button" disabled={loading} type="submit">
                <Send size={16} />
                {loading ? 'Đang gửi...' : 'Gửi thông báo'}
              </button>
            </form>
          )}
        </div>
      </div>
    </div>
  );
}

function UserDetail({ user, report, transactions, budgets, onUpdateUser }) {
  const [saving, setSaving] = useState(false);

  async function handleUpdate(updates) {
    setSaving(true);
    try {
      await onUpdateUser(user.id, updates);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="detail-stack">
      <div className="profile-strip">
        <Avatar user={user} large />
        <div>
          <h2>{user.fullName || 'Chưa đặt tên'}</h2>
          <p>{user.email || user.id}</p>
          <small>UID: {user.id}</small>
        </div>
      </div>

      <div className="detail-actions">
        <label>
          Trạng thái
          <select
            value={user.status || 'active'}
            disabled={saving}
            onChange={(event) => handleUpdate({ status: event.target.value })}
          >
            <option value="active">Hoạt động</option>
            <option value="locked">Đã khóa</option>
          </select>
        </label>
      </div>

      <div className="mini-metrics">
        <MiniMetric label="Thu" value={formatVnd(report.income)} />
        <MiniMetric label="Chi" value={formatVnd(report.expense)} />
        <MiniMetric label="Số dư" value={formatVnd(report.balance)} />
        <MiniMetric label="Giao dịch" value={transactions.length} />
      </div>

      <div className="split-list">
        <div>
          <h3>Giao dịch gần đây</h3>
          <div className="transaction-list">
            {transactions.slice(0, 8).map((item) => (
              <div key={item.id} className="transaction-row">
                <span>
                  <strong>{item.title || item.category}</strong>
                  <small>
                    {item.category} • {formatDate(item.transactionDate)}
                  </small>
                </span>
                <strong className={item.type === 'income' ? 'income' : 'expense'}>
                  {item.type === 'income' ? '+' : '-'}
                  {formatVnd(item.amount)}
                </strong>
              </div>
            ))}
            {transactions.length === 0 && (
              <p className="empty-text">User này chưa có giao dịch.</p>
            )}
          </div>
        </div>

        <div>
          <h3>Ngân sách</h3>
          <div className="budget-list">
            {budgets.map((budget) => (
              <div key={budget.id} className="budget-row">
                <span>{budget.category}</span>
                <strong>{formatVnd(budget.limitAmount)}</strong>
              </div>
            ))}
            {budgets.length === 0 && (
              <p className="empty-text">Chưa đặt ngân sách.</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function MetricCard({ title, value, icon, tone }) {
  return (
    <article className={`metric-card ${tone}`}>
      <div className="metric-icon">{icon}</div>
      <span>{title}</span>
      <strong>{value}</strong>
    </article>
  );
}

function MiniMetric({ label, value }) {
  return (
    <div className="mini-card">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function Panel({ title, children }) {
  return (
    <section className="panel">
      <div className="panel-title">
        <h2>{title}</h2>
      </div>
      {children}
    </section>
  );
}

function BarReport({ items }) {
  const [hoveredBar, setHoveredBar] = useState(null);
  const width = Math.max(720, items.length * 72 + 116);
  const height = 320;
  const padding = { top: 24, right: 24, bottom: 46, left: 92 };
  const plotWidth = width - padding.left - padding.right;
  const plotHeight = height - padding.top - padding.bottom;
  const max = Math.max(...items.map((item) => Math.max(item.income, item.expense)), 1);
  const ticks = buildAxisTicks(0, max, 4);
  const groupWidth = plotWidth / items.length;
  const barWidth = Math.min(30, groupWidth / 3);

  return (
    <div className="axis-chart-wrap">
      <div className="chart-legend-row">
        <span className="chart-legend-dot income-dot" />
        <span className="chart-legend-label">Thu nhập</span>
        <span className="chart-legend-dot expense-dot" />
        <span className="chart-legend-label">Chi tiêu</span>
      </div>
      <svg
        className="axis-chart bar-axis-chart"
        style={{ width: `${width}px` }}
        viewBox={`0 0 ${width} ${height}`}
        role="img"
      >
        <defs>
          <linearGradient id="incomeGrad" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stopColor="#00c49a" />
            <stop offset="100%" stopColor="#00796b" />
          </linearGradient>
          <linearGradient id="expenseGrad" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stopColor="#ff6b6b" />
            <stop offset="100%" stopColor="#d43d3d" />
          </linearGradient>
        </defs>
        {ticks.map((tick) => {
          const y = padding.top + plotHeight - (tick / max) * plotHeight;
          return (
            <g key={tick}>
              <line
                x1={padding.left}
                x2={width - padding.right}
                y1={y}
                y2={y}
                className="chart-grid-line"
                strokeDasharray={tick === 0 ? '0' : '4 4'}
              />
              <text x={padding.left - 12} y={y + 4} textAnchor="end">
                {formatAxisVnd(tick)}
              </text>
            </g>
          );
        })}

        <line
          x1={padding.left}
          x2={padding.left}
          y1={padding.top}
          y2={height - padding.bottom}
          className="chart-axis-line"
        />
        <line
          x1={padding.left}
          x2={width - padding.right}
          y1={height - padding.bottom}
          y2={height - padding.bottom}
          className="chart-axis-line"
        />

        {items.map((item, index) => {
          const x = padding.left + index * groupWidth + groupWidth / 2;
          const incomeHeight = Math.max((item.income / max) * plotHeight, item.income > 0 ? 3 : 0);
          const expenseHeight = Math.max((item.expense / max) * plotHeight, item.expense > 0 ? 3 : 0);
          const isHovered = hoveredBar === item.key;
          return (
            <g
              key={item.key}
              onMouseEnter={() => setHoveredBar(item.key)}
              onMouseLeave={() => setHoveredBar(null)}
              style={{ cursor: 'pointer' }}
            >
              {isHovered && (
                <rect
                  x={x - barWidth - 10}
                  y={padding.top}
                  width={barWidth * 2 + 26}
                  height={plotHeight}
                  rx="6"
                  fill="rgba(0,121,107,0.06)"
                />
              )}
              <rect
                x={x - barWidth - 3}
                y={height - padding.bottom - incomeHeight}
                width={barWidth}
                height={incomeHeight}
                rx="5"
                fill="url(#incomeGrad)"
                opacity={isHovered ? 1 : 0.88}
              >
                <title>{`${item.label} - Thu: ${formatVnd(item.income)}`}</title>
              </rect>
              <rect
                x={x + 3}
                y={height - padding.bottom - expenseHeight}
                width={barWidth}
                height={expenseHeight}
                rx="5"
                fill="url(#expenseGrad)"
                opacity={isHovered ? 1 : 0.88}
              >
                <title>{`${item.label} - Chi: ${formatVnd(item.expense)}`}</title>
              </rect>
              <text x={x} y={height - 16} textAnchor="middle" fontWeight={isHovered ? '900' : '700'}>
                {item.label}
              </text>
              {isHovered && (
                <g>
                  <rect
                    x={x - 56}
                    y={padding.top - 4}
                    width={112}
                    height={44}
                    rx="6"
                    fill="#0b4039"
                    opacity="0.92"
                  />
                  <text x={x} y={padding.top + 13} textAnchor="middle" fill="#a8ded4" fontSize="11" fontWeight="700">
                    Thu: {formatAxisVnd(item.income)}
                  </text>
                  <text x={x} y={padding.top + 29} textAnchor="middle" fill="#ffb3b3" fontSize="11" fontWeight="700">
                    Chi: {formatAxisVnd(item.expense)}
                  </text>
                </g>
              )}
            </g>
          );
        })}
      </svg>
    </div>
  );
}

function CategoryReport({ items }) {
  if (items.length === 0) {
    return <p className="empty-text">Chưa có dữ liệu chi tiêu.</p>;
  }

  const max = Math.max(...items.map((item) => item.amount), 1);
  return (
    <div className="category-report">
      {items.slice(0, 6).map((item) => (
        <div key={item.category} className="category-row">
          <div>
            <strong>{item.category}</strong>
            <span>{formatVnd(item.amount)}</span>
          </div>
          <div className="progress-track">
            <div
              className="progress-fill"
              style={{ width: `${(item.amount / max) * 100}%` }}
            />
          </div>
        </div>
      ))}
    </div>
  );
}

function DonutChart({ items }) {
  if (items.length === 0) {
    return <p className="empty-text">Chưa có dữ liệu chi tiêu.</p>;
  }

  const total = items.reduce((sum, item) => sum + item.amount, 0);
  if (total <= 0) {
    return <p className="empty-text">Chưa có dữ liệu chi tiêu.</p>;
  }
  const slices = compactChartItems(items);
  let cursor = 0;
  const gradient = slices
    .map((item, index) => {
      const start = cursor;
      cursor += (item.amount / total) * 100;
      return `${chartPalette[index % chartPalette.length]} ${start}% ${cursor}%`;
    })
    .join(', ');

  return (
    <div className="donut-layout">
      <div
        className="donut-chart"
        style={{ background: `conic-gradient(${gradient})` }}
        aria-label="Tỷ trọng chi tiêu theo danh mục"
      >
        <div className="donut-hole">
          <span>Tổng chi</span>
          <strong>{formatVnd(total)}</strong>
        </div>
      </div>
      <div className="chart-legend">
        {slices.map((item, index) => (
          <div key={item.category} className="legend-row">
            <span
              className="legend-dot"
              style={{ background: chartPalette[index % chartPalette.length] }}
            />
            <span>{item.category}</span>
            <strong>{Math.round((item.amount / total) * 100)}%</strong>
          </div>
        ))}
      </div>
    </div>
  );
}

function BalanceLineChart({ items }) {
  const values = items.map((item) => item.income - item.expense);
  if (values.length === 0) {
    return <p className="empty-text">Chưa có dữ liệu theo tháng.</p>;
  }

  const width = Math.max(720, items.length * 72 + 116);
  const height = 320;
  const padding = { top: 24, right: 24, bottom: 46, left: 92 };
  const plotWidth = width - padding.left - padding.right;
  const plotHeight = height - padding.top - padding.bottom;
  const min = Math.min(...values, 0);
  const max = Math.max(...values, 0);
  const range = max - min || 1;
  const ticks = buildAxisTicks(min, max, 4);
  const xStep = values.length > 1 ? plotWidth / (values.length - 1) : 0;
  const points = values.map((value, index) => {
    const x = padding.left + index * xStep;
    const y = padding.top + plotHeight - ((value - min) / range) * plotHeight;
    return { x, y, value, label: items[index].label };
  });
  const path = points
    .map((point, index) => `${index === 0 ? 'M' : 'L'} ${point.x} ${point.y}`)
    .join(' ');
  const baselineY = padding.top + plotHeight - ((0 - min) / range) * plotHeight;
  const areaPath = `${path} L ${points.at(-1).x} ${height - padding.bottom} L ${points[0].x} ${height - padding.bottom} Z`;

  return (
    <div className="line-chart-wrap">
      <svg
        className="line-chart"
        style={{ width: `${width}px` }}
        viewBox={`0 0 ${width} ${height}`}
        role="img"
      >
        <defs>
          <linearGradient id="balanceFill" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stopColor="#00796b" stopOpacity="0.26" />
            <stop offset="100%" stopColor="#00796b" stopOpacity="0.02" />
          </linearGradient>
        </defs>
        {ticks.map((tick) => {
          const y = padding.top + plotHeight - ((tick - min) / range) * plotHeight;
          return (
            <g key={tick}>
              <line
                x1={padding.left}
                x2={width - padding.right}
                y1={y}
                y2={y}
                className="chart-grid-line"
              />
              <text x={padding.left - 12} y={y + 4} textAnchor="end">
                {formatAxisVnd(tick)}
              </text>
            </g>
          );
        })}
        <line
          x1={padding.left}
          x2={padding.left}
          y1={padding.top}
          y2={height - padding.bottom}
          className="chart-axis-line"
        />
        <line
          x1={padding.left}
          x2={width - padding.right}
          y1={height - padding.bottom}
          y2={height - padding.bottom}
          className="chart-axis-line"
        />
        <line
          x1={padding.left}
          x2={width - padding.right}
          y1={baselineY}
          y2={baselineY}
          className="line-chart-zero"
        />
        <path d={areaPath} className="line-chart-area" />
        <path d={path} className="line-chart-path" />
        {points.map((point) => (
          <g key={point.label}>
            <circle cx={point.x} cy={point.y} r="5" className="line-chart-dot" />
            <title>{`${point.label}: ${formatVnd(point.value)}`}</title>
            <text x={point.x} y={height - 16} textAnchor="middle">
              {point.label}
            </text>
          </g>
        ))}
      </svg>
      <div className="line-chart-summary">
        <span>Trục X: tháng</span>
        <span>Trục Y: số dư VND</span>
        <span>Thấp nhất: {formatVnd(min)}</span>
        <span>Cao nhất: {formatVnd(max)}</span>
      </div>
    </div>
  );
}

function Avatar({ user, large = false }) {
  if (user.avatarUrl) {
    return (
      <img
        className={large ? 'avatar large' : 'avatar'}
        src={user.avatarUrl}
        alt={user.fullName || user.email || 'User'}
      />
    );
  }

  return (
    <div className={large ? 'avatar fallback large' : 'avatar fallback'}>
      {(user.fullName || user.email || 'U').slice(0, 1).toUpperCase()}
    </div>
  );
}

function Badge({ children, tone = 'muted' }) {
  return <span className={`badge ${tone}`}>{children}</span>;
}


function FullPageState({ title, compact = false }) {
  return (
    <main className={compact ? 'state-box compact' : 'state-box'}>
      <div className="spinner" />
      <p>{title}</p>
    </main>
  );
}

function buildReport(transactions, userCount, range = null) {
  const income = transactions
    .filter((item) => item.type === 'income')
    .reduce((sum, item) => sum + item.amount, 0);
  const expense = transactions
    .filter((item) => item.type === 'expense')
    .reduce((sum, item) => sum + item.amount, 0);

  const categories = Object.values(
    transactions
      .filter((item) => item.type === 'expense')
      .reduce((acc, item) => {
        acc[item.category] ||= { category: item.category, amount: 0 };
        acc[item.category].amount += item.amount;
        return acc;
      }, {}),
  ).sort((a, b) => b.amount - a.amount);

  return {
    userCount,
    income,
    expense,
    balance: income - expense,
    categories,
    monthly: buildMonthlyReport(transactions, range),
  };
}

function resolveReportRange(preset, startDate, endDate) {
  const now = new Date();
  let start = null;
  let end = endOfDay(now);
  let label = '6 tháng gần đây';

  if (preset === 'thisMonth') {
    start = startOfMonth(now);
    label = 'Tháng này';
  } else if (preset === 'last3') {
    start = startOfMonth(addMonths(now, -2));
    label = '3 tháng gần đây';
  } else if (preset === 'last6') {
    start = startOfMonth(addMonths(now, -5));
    label = '6 tháng gần đây';
  } else if (preset === 'year') {
    start = new Date(now.getFullYear(), 0, 1);
    label = 'Năm nay';
  } else if (preset === 'all') {
    end = null;
    label = 'Tất cả thời gian';
  } else if (preset === 'custom') {
    start = parseInputStartDate(startDate);
    end = parseInputEndDate(endDate);

    if (start && end && start.getTime() > end.getTime()) {
      [start, end] = [startOfDay(end), endOfDay(start)];
    }

    label = formatCustomRangeLabel(start, end);
  }

  return {
    preset,
    startDate: start,
    endDate: end,
    startMs: start?.getTime() ?? null,
    endMs: end?.getTime() ?? null,
    label,
  };
}

function filterTransactionsByRange(transactions, range) {
  return transactions.filter((transaction) => {
    if (range.startMs != null && transaction.transactionDateMs < range.startMs) {
      return false;
    }
    if (range.endMs != null && transaction.transactionDateMs > range.endMs) {
      return false;
    }
    return true;
  });
}

function buildAccountSummary(users) {
  return users.reduce(
    (summary, user) => {
      if (user.status === 'locked') {
        summary.locked += 1;
      } else {
        summary.active += 1;
      }

      if (user.role === 'admin') summary.admins += 1;
      if (user.hasCompletedOnboarding) summary.onboarded += 1;
      return summary;
    },
    { active: 0, locked: 0, admins: 0, onboarded: 0 },
  );
}

function buildUserRankings(users, transactions) {
  const byUser = users.reduce((acc, user) => {
    acc[user.id] = {
      id: user.id,
      fullName: user.fullName,
      email: user.email,
      income: 0,
      expense: 0,
      count: 0,
    };
    return acc;
  }, {});

  transactions.forEach((transaction) => {
    if (!byUser[transaction.userId]) {
      byUser[transaction.userId] = {
        id: transaction.userId,
        fullName: '',
        email: '',
        income: 0,
        expense: 0,
        count: 0,
      };
    }

    byUser[transaction.userId].count += 1;
    if (transaction.type === 'income') {
      byUser[transaction.userId].income += transaction.amount;
    } else {
      byUser[transaction.userId].expense += transaction.amount;
    }
  });

  return Object.values(byUser).sort((a, b) => b.expense - a.expense);
}

function buildAxisTicks(min, max, steps) {
  if (min === max) return [min];
  const interval = (max - min) / steps;
  return Array.from({ length: steps + 1 }, (_, index) => min + interval * index);
}

function formatAxisVnd(value) {
  const rounded = Math.round(value);
  const abs = Math.abs(rounded);
  if (abs >= 1000000000) return `${trimAxisNumber(rounded / 1000000000)}B`;
  if (abs >= 1000000) return `${trimAxisNumber(rounded / 1000000)}M`;
  if (abs >= 1000) return `${trimAxisNumber(rounded / 1000)}K`;
  return `${rounded}`;
}

function trimAxisNumber(value) {
  return Number.isInteger(value) ? `${value}` : value.toFixed(1);
}

function compactChartItems(items) {
  const topItems = items.slice(0, 5);
  const rest = items.slice(5).reduce((sum, item) => sum + item.amount, 0);
  if (rest <= 0) return topItems;
  return [...topItems, { category: 'Khác', amount: rest }];
}

function buildMonthlyReport(transactions, range = null) {
  const months = buildReportMonths(transactions, range);
  const groupByCalendarMonth = months.length > 12;
  const items = groupByCalendarMonth
    ? Array.from({ length: 12 }, (_, index) => ({
      key: `month-${index + 1}`,
      label: `T${index + 1}`,
    }))
    : months.map((date) => ({
      key: monthKey(date),
      label: formatMonthAxisLabel(date),
    }));
  const buckets = items.reduce((acc, item) => {
    acc[item.key] = { income: 0, expense: 0 };
    return acc;
  }, {});

  transactions.forEach((transaction) => {
    const key = groupByCalendarMonth
      ? calendarMonthKey(transaction.transactionDate)
      : monthKey(transaction.transactionDate);
    const bucket = buckets[key];
    if (!bucket) return;

    if (transaction.type === 'income') {
      bucket.income += transaction.amount;
    } else {
      bucket.expense += transaction.amount;
    }
  });

  return items.map((item) => ({
    ...item,
    income: buckets[item.key].income,
    expense: buckets[item.key].expense,
  }));
}

function buildReportMonths(transactions, range) {
  let start = range?.startDate ? startOfMonth(range.startDate) : null;
  let end = range?.endDate ? startOfMonth(range.endDate) : null;

  if (!start && !end && transactions.length > 0) {
    const dates = transactions.map((transaction) => transaction.transactionDate);
    start = startOfMonth(new Date(Math.min(...dates.map((date) => date.getTime()))));
    end = startOfMonth(new Date(Math.max(...dates.map((date) => date.getTime()))));
  }

  if (!start && !end) {
    end = startOfMonth(new Date());
    start = addMonths(end, -5);
  } else if (start && !end) {
    end = startOfMonth(new Date());
  } else if (!start && end) {
    start = addMonths(end, -5);
  }

  if (start.getTime() > end.getTime()) {
    [start, end] = [end, start];
  }

  const months = [];
  for (let cursor = startOfMonth(start); cursor <= end; cursor = addMonths(cursor, 1)) {
    months.push(cursor);
  }
  return months;
}

function startOfDay(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function endOfDay(date) {
  return new Date(
    date.getFullYear(),
    date.getMonth(),
    date.getDate(),
    23,
    59,
    59,
    999,
  );
}

function startOfMonth(date) {
  return new Date(date.getFullYear(), date.getMonth(), 1);
}

function addMonths(date, amount) {
  return new Date(date.getFullYear(), date.getMonth() + amount, 1);
}

function monthDistance(start, end) {
  return (end.getFullYear() - start.getFullYear()) * 12
    + end.getMonth()
    - start.getMonth();
}

function parseInputStartDate(value) {
  if (!value) return null;
  const date = new Date(`${value}T00:00:00`);
  return Number.isNaN(date.getTime()) ? null : date;
}

function parseInputEndDate(value) {
  if (!value) return null;
  const date = new Date(`${value}T23:59:59.999`);
  return Number.isNaN(date.getTime()) ? null : date;
}

function formatCustomRangeLabel(start, end) {
  if (start && end) return `${formatShortDate(start)} - ${formatShortDate(end)}`;
  if (start) return `Từ ${formatShortDate(start)}`;
  if (end) return `Đến ${formatShortDate(end)}`;
  return 'Tùy chọn: tất cả thời gian';
}

function formatShortDate(date) {
  return new Intl.DateTimeFormat('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(date);
}

function formatMonthAxisLabel(date) {
  return `T${date.getMonth() + 1}`;
}

function normalizeUser(snapshot) {
  const data = snapshot.data();
  const createdAt = toDate(data.createdAt);
  return {
    id: snapshot.id,
    fullName: data.fullName || '',
    email: data.email || '',
    avatarUrl: data.avatarUrl || '',
    role: data.role || 'user',
    status: data.status || 'active',
    hasCompletedOnboarding: Boolean(data.hasCompletedOnboarding),
    createdAt,
    createdAtMs: createdAt?.getTime() || 0,
  };
}

function normalizeTransaction(snapshot) {
  const data = snapshot.data();
  const date = toDate(data.transactionDate) || new Date();
  return {
    id: snapshot.id,
    userId: snapshot.ref.parent.parent?.id || '',
    type: data.type || 'expense',
    amount: Number(data.amount || 0),
    category: data.category || 'Khác',
    title: data.title || '',
    note: data.note || '',
    paymentMethod: data.paymentMethod || '',
    transactionDate: date,
    transactionDateMs: date.getTime(),
  };
}

function normalizeBudget(snapshot) {
  const data = snapshot.data();
  return {
    id: snapshot.id,
    userId: snapshot.ref.parent.parent?.id || '',
    category: data.category || 'Khác',
    limitAmount: Number(data.limitAmount || 0),
    period: data.period || 'monthly',
    periodKey: data.periodKey || '',
  };
}

function normalizeDocument(snapshot) {
  const data = snapshot.data();
  const createdAt = toDate(data.createdAt);
  const updatedAt = toDate(data.updatedAt);
  return {
    id: snapshot.id,
    title: data.title || '',
    description: data.description || '',
    category: data.category || 'Chung',
    fileName: data.fileName || '',
    fileUrl: data.fileUrl || '',
    storagePath: data.storagePath || '',
    isPublished: Boolean(data.isPublished),
    source: data.source || '',
    uploadedBy: data.uploadedBy || '',
    userId: data.userId || data.uploadedBy || '',
    userName: data.userName || '',
    userEmail: data.userEmail || '',
    periodLabel: data.periodLabel || '',
    createdAt,
    updatedAt,
    createdAtMs: createdAt?.getTime() || 0,
  };
}

function normalizeBugReport(snapshot) {
  const data = snapshot.data();
  const createdAt = toDate(data.createdAt);
  const updatedAt = toDate(data.updatedAt);
  return {
    id: snapshot.id,
    userId: data.userId || '',
    userEmail: data.userEmail || '',
    userName: data.userName || '',
    title: data.title || '',
    description: data.description || '',
    severity: data.severity || 'medium',
    status: data.status || 'pending',
    screenName: data.screenName || '',
    imageUrl: data.imageUrl || '',
    createdAt,
    updatedAt,
    createdAtMs: createdAt?.getTime() || 0,
  };
}

function normalizeCampaign(snapshot) {
  const data = snapshot.data();
  const createdAt = toDate(data.createdAt);
  const sentAt = toDate(data.sentAt);
  return {
    id: snapshot.id,
    title: data.title || '',
    body: data.body || '',
    status: data.status || 'draft',
    targetType: data.targetType || 'all',
    targetUserCount: Number(data.targetUserCount || 0),
    sentCount: Number(data.sentCount || 0),
    failedCount: Number(data.failedCount || 0),
    createdAt,
    sentAt,
    createdAtMs: createdAt?.getTime() || 0,
  };
}

function normalizeCampaignRecipient(snapshot) {
  const data = snapshot.data();
  return {
    id: snapshot.id,
    campaignId: snapshot.ref.parent.parent?.id || '',
    userId: data.userId || snapshot.id,
    notificationId: data.notificationId || '',
    isRead: Boolean(data.isRead),
    openedAt: toDate(data.openedAt),
    readAt: toDate(data.readAt),
  };
}

function buildCampaignStats(campaigns, recipients) {
  const recipientsByCampaign = recipients.reduce((acc, recipient) => {
    acc[recipient.campaignId] ||= [];
    acc[recipient.campaignId].push(recipient);
    return acc;
  }, {});

  return campaigns.map((campaign) => {
    const campaignRecipients = recipientsByCampaign[campaign.id] || [];
    return {
      ...campaign,
      openedCount: campaignRecipients.filter((item) => item.openedAt).length,
      readCount: campaignRecipients.filter((item) => item.isRead || item.readAt).length,
      targetUserCount: campaign.targetUserCount || campaignRecipients.length,
    };
  });
}

function bugStatusLabel(status) {
  if (status === 'in_progress') return 'Đang xử lý';
  if (status === 'resolved') return 'Đã xử lý';
  if (status === 'rejected') return 'Từ chối';
  return 'Chờ xử lý';
}

function bugStatusTone(status) {
  if (status === 'resolved') return 'primary';
  if (status === 'rejected') return 'danger';
  return 'muted';
}

function toDate(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate();
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function monthKey(date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
}

function calendarMonthKey(date) {
  return `month-${date.getMonth() + 1}`;
}

function formatVnd(value) {
  return currency.format(Math.round(value || 0));
}

function formatDate(date) {
  return new Intl.DateTimeFormat('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(date);
}

function firebaseAuthMessage(error) {
  if (error.code === 'auth/invalid-credential') {
    return 'Email hoặc mật khẩu không đúng.';
  }
  if (error.code === 'auth/user-disabled') {
    return 'Tài khoản đã bị vô hiệu hóa.';
  }
  return error.message || 'Không thể đăng nhập.';
}

function firestoreMessage(error) {
  if (error.code === 'permission-denied') {
    return 'Firestore Rules chưa cho phép admin đọc dữ liệu. Hãy deploy/paste firestore.rules mới.';
  }
  return error.message || 'Không thể đọc dữ liệu Firestore.';
}

export default App;
