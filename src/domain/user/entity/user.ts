export type UserProps = {
  id: string;
  name: string;
  email: string;
};

export class User {
  private props: UserProps;
  private constructor(props: UserProps) {
    this.props = props;
    this.validate();
  }

  public static create(name: string, email: string) {
    return new User({
      id: crypto.randomUUID().toString(),
      name,
      email,
    });
  }

  public static with(props: UserProps): User {
    return new User(props);
  }

  private validate() {
    const name = (this.props?.name ?? '').trim();
    const email = (this.props?.email ?? '').trim();

    if (!name) {
      throw new Error('Invalid name: must not be empty');
    }

    if (name.length > 100) {
      throw new Error('Invalid name: must be 100 characters or fewer');
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new Error('Invalid email: must be a valid email address');
    }
  }

  get id(): string {
    return this.props.id;
  }

  get name(): string {
    return this.props.name;
  }

  get email(): string {
    return this.props.email;
  }
}
