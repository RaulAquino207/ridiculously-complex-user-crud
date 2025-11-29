export type UserProps = {
  id: string;
  name: string;
  email: string;
};

export class User {
  private props: UserProps;
  constructor(props: UserProps) {
    this.props = props;
  }

  public static create(name: string, email: string) {
    return new User({
      id: crypto.randomUUID().toString(),
      name,
      email,
    });
  }

  public static with(props: UserProps) {
    return new User(props);
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
