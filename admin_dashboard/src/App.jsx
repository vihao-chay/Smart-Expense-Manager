import { useEffect, useMemo, useState } from 'react';
import {
  BarChart3,
  CalendarDays,
  CheckCircle2,
  CircleDollarSign,
  Lock,
  LogOut,
  RefreshCcw,
  Search,
  ShieldCheck,
  TrendingDown,
  TrendingUp,
  UserCog,
  Users,
  Wallet,
} from 'lucide-react';
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import {
  collection,
  collectionGroup,
  doc,
  getDoc,
  onSnapshot,
  serverTimestamp,
  updateDoc,
} from 'firebase/firestore';

import { auth, db } from './firebase';

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

    return () => unsubscribers.forEach((unsubscribe) => unsubscribe());
  }, []);

  const appUsers = useMemo(
    () => usersData.filter((user) => user.role !== 'admin'),
    [usersData],
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
  const viewTitle = {
    overview: 'Tổng quan hệ thống',
    users: 'Quản lý người dùng',
    reports: 'Báo cáo tài chính',
  }[activeView];

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
            <h1 className="dynamic-title">{viewTitle}</h1>
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
              <section id="users" className="users-layout">
              <Panel title="Người dùng">
                <div className="search-box">
                  <Search size={18} />
                  <input
                    value={queryText}
                    onChange={(event) => setQueryText(event.target.value)}
                    placeholder="Tìm theo tên, email, UID..."
                  />
                </div>
                <div className="user-list">
                  {filteredUsers.map((user) => (
                    <button
                      key={user.id}
                      className={[
                        'user-row',
                        user.id === selectedUser?.id ? 'selected' : '',
                        user.status === 'locked' ? 'locked' : '',
                      ].join(' ')}
                      onClick={() => setSelectedUserId(user.id)}
                    >
                      <Avatar user={user} />
                      <span>
                        <strong>{user.fullName || 'Chưa đặt tên'}</strong>
                        <small>{user.email || user.id}</small>
                      </span>
                      <Badge tone={user.status === 'locked' ? 'danger' : 'muted'}>
                        {user.status || 'active'}
                      </Badge>
                    </button>
                  ))}
                </div>
              </Panel>

              <Panel title="Chi tiết user">
                {selectedUser ? (
                  <UserDetail
                    user={selectedUser}
                    report={userReport}
                    transactions={selectedTransactions}
                    budgets={selectedBudgets}
                    onUpdateUser={updateUser}
                  />
                ) : (
                  <p className="empty-text">Chưa có user nào.</p>
                )}
              </Panel>
              </section>
            )}
          </>
        )}
      </main>
    </div>
  );
}

function AccountStatus({ summary }) {
  return (
    <div className="status-grid">
      <div className="status-card">
        <CheckCircle2 size={22} />
        <span>Active</span>
        <strong>{summary.active}</strong>
      </div>
      <div className="status-card warning">
        <Lock size={22} />
        <span>Locked</span>
        <strong>{summary.locked}</strong>
      </div>
      <div className="status-card info">
        <UserCog size={22} />
        <span>Admin</span>
        <strong>{summary.admins}</strong>
      </div>
      <div className="status-card muted">
        <ShieldCheck size={22} />
        <span>Onboarded</span>
        <strong>{summary.onboarded}</strong>
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
            <option value="active">active</option>
            <option value="locked">locked</option>
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
  const width = Math.max(720, items.length * 72 + 116);
  const height = 320;
  const padding = { top: 24, right: 24, bottom: 46, left: 92 };
  const plotWidth = width - padding.left - padding.right;
  const plotHeight = height - padding.top - padding.bottom;
  const max = Math.max(...items.map((item) => Math.max(item.income, item.expense)), 1);
  const ticks = buildAxisTicks(0, max, 4);
  const groupWidth = plotWidth / items.length;
  const barWidth = Math.min(28, groupWidth / 3.2);

  return (
    <div className="axis-chart-wrap">
      <svg
        className="axis-chart bar-axis-chart"
        style={{ width: `${width}px` }}
        viewBox={`0 0 ${width} ${height}`}
        role="img"
      >
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
          return (
            <g key={item.key}>
              <rect
                x={x - barWidth - 3}
                y={height - padding.bottom - incomeHeight}
                width={barWidth}
                height={incomeHeight}
                rx="6"
                className="income-bar-svg"
              >
                <title>{`${item.label} - Thu: ${formatVnd(item.income)}`}</title>
              </rect>
              <rect
                x={x + 3}
                y={height - padding.bottom - expenseHeight}
                width={barWidth}
                height={expenseHeight}
                rx="6"
                className="expense-bar-svg"
              >
                <title>{`${item.label} - Chi: ${formatVnd(item.expense)}`}</title>
              </rect>
              <text x={x} y={height - 16} textAnchor="middle">
                {item.label}
              </text>
            </g>
          );
        })}
      </svg>
      <div className="chart-axis-caption">
        <span>Trục X: tháng</span>
        <span>Trục Y: giá trị VND</span>
      </div>
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
